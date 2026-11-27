#!/usr/bin/env python3
"""Dictation for DictationService.

    dictation.py serve   takes commands on stdin and reports on stdout, a JSON object to a
                         line, until stdin closes
    dictation.py type    types its stdin into the focused window with wtype

Whisper isn't a streaming model, so the words show as they're spoken by transcribing what
hasn't settled yet every half second or so, through whisper.cpp's server, which keeps the
model loaded from one dictation to the next while this runs. Words two passes in a row agree
on settle, and the rest show as pending. Once the recording stops, one pass over all of it
gives the text.

Commands: {"cmd": "start", "model": FILE or "", "languages": [CODE, ...], "vocabulary":
TEXT}, {"cmd": "stop"}, and {"cmd": "cancel"}.
Events: {"event": "status", "status": "downloading" (with "progress", 0 to 1), "loading",
or "listening"}; {"event": "level", "value": 0 to 1}; {"event": "text", "settled": TEXT,
"pending": TEXT}; {"event": "final", "text": TEXT}; and {"event": "error", "message": TEXT}.
"""

import array
import io
import json
import math
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
import wave
from pathlib import Path

RATE = 16000
SECOND = RATE * 2
# Loudness is measured over 30 ms frames, to tell speech from silence.
FRAME = 480
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/"
DEFAULT_MODEL = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "speshell/whisper"
DEFAULT_MODEL /= "ggml-large-v3-turbo-q5_0.bin"
# Whisper's languages, by the names its server reports them with.
LANGUAGES = """
        en:english zh:chinese de:german es:spanish ru:russian ko:korean fr:french ja:japanese pt:portuguese
        tr:turkish pl:polish ca:catalan nl:dutch ar:arabic sv:swedish it:italian id:indonesian hi:hindi fi:finnish
        vi:vietnamese he:hebrew uk:ukrainian el:greek ms:malay cs:czech ro:romanian da:danish hu:hungarian ta:tamil
        no:norwegian th:thai ur:urdu hr:croatian bg:bulgarian lt:lithuanian la:latin mi:maori ml:malayalam cy:welsh
        sk:slovak te:telugu fa:persian lv:latvian bn:bengali sr:serbian az:azerbaijani sl:slovenian kn:kannada
        et:estonian mk:macedonian br:breton eu:basque is:icelandic hy:armenian ne:nepali mn:mongolian bs:bosnian
        kk:kazakh sq:albanian sw:swahili gl:galician mr:marathi pa:punjabi si:sinhala km:khmer sn:shona yo:yoruba
        so:somali af:afrikaans oc:occitan ka:georgian be:belarusian tg:tajik sd:sindhi gu:gujarati am:amharic
        yi:yiddish lo:lao uz:uzbek fo:faroese ht:haitian_creole ps:pashto tk:turkmen nn:nynorsk mt:maltese
        sa:sanskrit lb:luxembourgish my:myanmar bo:tibetan tl:tagalog mg:malagasy as:assamese tt:tatar haw:hawaiian
        ln:lingala ha:hausa ba:bashkir jw:javanese su:sundanese yue:cantonese
"""
LANGUAGE_CODES = {name.replace("_", " "): code for code, name in (pair.split(":") for pair in LANGUAGES.split())}
# Languages short clips get mistaken for one another.
FAMILIES = ("pt es gl ca it fr ro la oc", "en de nl af da sv no nn is lb")

_output = threading.Lock()


class Failure(Exception):
    """What went wrong, for the user, ending the dictation."""


def emit(event, **fields):
    with _output:
        try:
            sys.stdout.write(json.dumps({"event": event, **fields}) + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            os._exit(0)


def child(command):
    """command, ended with this helper however it ends, since it runs from the main thread."""
    return ["setpriv", "--pdeathsig", "TERM", "--", *command]


def closest_language(code, allowed):
    """The allowed language in code's family, else the first allowed."""
    for family in map(str.split, FAMILIES):
        if code in family:
            for candidate in allowed:
                if candidate in family:
                    return candidate
    return allowed[0]


def wav(pcm):
    """The 16 kHz mono samples pcm as a WAV file."""
    out = io.BytesIO()
    with wave.open(out, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm)
    return out.getvalue()


def multipart(fields):
    """fields as a multipart/form-data body, and its content type; a tuple is a file."""
    boundary = uuid.uuid4().hex
    body = bytearray()
    for name, value in fields.items():
        body += f"--{boundary}\r\n".encode()
        if isinstance(value, tuple):
            filename, data, kind = value
            body += f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode()
            body += f"Content-Type: {kind}\r\n\r\n".encode() + data
        else:
            body += f'Content-Disposition: form-data; name="{name}"\r\n\r\n{value}'.encode()
        body += b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return bytes(body), f"multipart/form-data; boundary={boundary}"


def speech_threshold(loudness):
    """The loudness over which a frame is speech: well over the room's noise."""
    if not loudness:
        return math.inf
    quiet = sorted(loudness[:: max(1, len(loudness) // 500)])
    return max(100.0, 3 * quiet[len(quiet) // 10])


def speech(loudness, threshold, since):
    """Seconds of speech after since."""
    return sum(1 for value in loudness[int(since * RATE / FRAME) :] if value > threshold) * FRAME / RATE


def words_of(result, offset):
    """What whisper heard, as (text, start, end) words timed from the recording's start: the
    pieces it splits words into joined, and anything it heard in silence dropped."""
    words = []
    for segment in result.get("segments", []):
        if segment.get("no_speech_prob", 0) > 0.6 or re.fullmatch(r"\s*[(\[].*[)\]]\s*", segment.get("text", "")):
            continue
        for piece in segment.get("words", []):
            text = piece.get("word", "")
            if not text.strip() or re.fullmatch(r"\s*\[_.*_\]\s*", text):
                continue
            start, end = piece["start"] + offset, piece["end"] + offset
            if words and not text.startswith(" "):
                words[-1] = (words[-1][0] + text, words[-1][1], end)
            else:
                words.append((text, start, end))
    return words


def norm(text):
    return re.sub(r"\W", "", text.lower())


def text_of(words):
    return re.sub(r"\s+", " ", "".join(word[0] for word in words)).strip()


def after_repeat(settled, words):
    """words, less any start that repeats the end of the settled ones, as whisper may hear
    again the last words before the audio it's given."""
    for count in range(min(5, len(settled), len(words)), 0, -1):
        if [norm(w[0]) for w in settled[-count:]] == [norm(w[0]) for w in words[:count]]:
            return words[count:]
    return words


def resume(words, settled):
    """Where words go on after the settled ones they start with: past them, or past the last
    of them where it's close by, as a pass may hear a word or two differently."""
    if [norm(word[0]) for word in words[: len(settled)]] == [norm(word[0]) for word in settled]:
        return len(settled)
    last = norm(settled[-1][0])
    near = range(max(0, len(settled) - 3), min(len(words), len(settled) + 3))
    found = [index for index in near if norm(words[index][0]) == last]
    return min(found, key=lambda index: abs(index + 1 - len(settled))) + 1 if found else len(settled)


def download(model):
    name = model.name
    if not re.fullmatch(r"ggml-[A-Za-z0-9._-]+\.bin", name):
        raise Failure(f"The speech model {model} doesn't exist.")
    part = model.with_name(name + ".part")
    reported = 0.0
    try:
        model.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(MODEL_URL + name, timeout=30) as response, open(part, "wb") as out:
            total = int(response.headers.get("Content-Length") or 0)
            done = 0
            while block := response.read(1 << 20):
                out.write(block)
                done += len(block)
                if total and time.monotonic() - reported > 0.25:
                    reported = time.monotonic()
                    emit("status", status="downloading", progress=round(done / total, 3))
        part.rename(model)
    except OSError as error:
        part.unlink(missing_ok=True)
        raise Failure(f"Couldn't download the speech model {name}.") from error


class Server:
    """whisper.cpp's server on a free local port, holding the model in memory. Its state
    is "stopped", "downloading", "downloaded", "starting", "ready", or "failed"."""

    def __init__(self, log):
        self.log = log
        self.model = None
        self.process = None
        self.url = ""
        self.state = "stopped"
        self.error = ""

    def prepare(self, model):
        """Has the server load model, downloading it first if it's missing."""
        alive = self.process is None or self.process.poll() is None
        if model == self.model and alive and self.state in ("downloading", "downloaded", "starting", "ready"):
            return
        self.stop()
        self.model = model
        if model.is_file():
            self.spawn()
        else:
            self.state = "downloading"
            emit("status", status="downloading", progress=0)
            threading.Thread(target=self.download, args=(model,), daemon=True).start()

    def download(self, model):
        try:
            download(model)
            if model == self.model:
                self.state = "downloaded"
        except Failure as error:
            if model == self.model:
                self.fail(str(error))

    def update(self):
        """Starts a server on a model just downloaded, and notices one that stopped."""
        if self.state == "downloaded":
            self.spawn()
        elif self.state in ("starting", "ready") and self.process.poll() is not None:
            lines = [line for line in self.log.read_text(errors="replace").splitlines() if line.strip()]
            self.fail("The speech server stopped" + (f": {lines[-1].strip()}" if lines else "."))

    def spawn(self):
        emit("status", status="loading")
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        self.url = f"http://127.0.0.1:{port}"
        command = ["whisper-server", "-m", str(self.model), "--host", "127.0.0.1", "--port", str(port), "-sns"]
        with open(self.log, "wb") as log:
            self.process = subprocess.Popen(
                child(command), stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT
            )
        self.state = "starting"
        threading.Thread(target=self.wait, args=(self.process,), daemon=True).start()

    def wait(self, process):
        while process.poll() is None:
            try:
                urllib.request.urlopen(self.url + "/", timeout=1).close()
            except OSError:
                time.sleep(0.1)
                continue
            if process is self.process and self.state == "starting":
                self.state = "ready"
            return

    def fail(self, error):
        self.stop()
        self.state = "failed"
        self.error = error

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(2)
            except subprocess.TimeoutExpired:
                self.process.kill()
        self.process = None
        self.model = None
        self.state = "stopped"

    def transcribe(self, pcm, language, prompt):
        """whisper's verbose JSON for the 16 kHz mono samples pcm."""
        body, kind = multipart(
            {
                "file": ("audio.wav", wav(pcm), "audio/wav"),
                "response_format": "verbose_json",
                "language": language,
                "prompt": prompt,
                "temperature": "0",
            }
        )
        request = urllib.request.Request(self.url + "/inference", data=body, headers={"Content-Type": kind})
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)


class Recorder:
    """The default microphone through pw-record: 16 kHz mono samples and each frame's
    loudness, with its level reported as it goes."""

    def __init__(self):
        self.pcm = bytearray()
        self.loudness = []
        self.lock = threading.Lock()
        command = ["pw-record", "--raw", f"--rate={RATE}", "--channels=1", "--format=s16", "-"]
        self.process = subprocess.Popen(
            child(command), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()

    def read(self):
        reported = 0.0
        while chunk := self.process.stdout.read(1600):
            with self.lock:
                self.pcm += chunk
                while (len(self.loudness) + 1) * FRAME * 2 <= len(self.pcm):
                    start = len(self.loudness) * FRAME * 2
                    samples = array.array("h", self.pcm[start : start + FRAME * 2])
                    self.loudness.append(math.sqrt(sum(s * s for s in samples) / FRAME))
                recent = max(self.loudness[-3:], default=0.0)
            if time.monotonic() - reported >= 0.08:
                reported = time.monotonic()
                emit("level", value=round(min(1.0, recent / 3000) ** 0.5, 2))

    def snapshot(self):
        with self.lock:
            return bytes(self.pcm), list(self.loudness)

    def failed(self):
        return self.process.poll() is not None and not self.pcm

    def stop(self):
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGINT)
            try:
                self.process.wait(1)
            except subprocess.TimeoutExpired:
                self.process.kill()
        self.reader.join(1)


class Session:
    """One dictation: its recording, and what the live passes made of it so far."""

    def __init__(self, languages, vocabulary):
        self.recorder = Recorder()
        self.languages = languages
        self.vocabulary = vocabulary.strip()
        # Fixed with one language allowed, else once a pass hears enough to tell.
        self.language = languages[0] if len(languages) == 1 else ""
        # Where the audio passes transcribe starts, in seconds, so they stay short however
        # long the dictation runs: a pause every word before settled in.
        self.offset = 0.0
        # The words that settled, the first `start` of them before the offset; the last
        # pass's words; and what of them is still to settle.
        self.settled = []
        self.start = 0
        self.previous = []
        self.pending = []
        # The recording's length at the last pass, and when it ran.
        self.heard = 0.0
        self.passed_at = 0.0
        self.listening = False
        self.stopping = False
        self.shown = ("", "")

    def prompt(self):
        """The vocabulary, for its spellings, and the end of what settled before the offset,
        for context."""
        return f"{self.vocabulary} {text_of(self.settled[: self.start])[-200:]}".strip()

    def step(self, server):
        """A live pass, when there's new speech to hear or pending words to settle. The words
        two passes in a row start with settle."""
        pcm, loudness = self.recorder.snapshot()
        length = len(pcm) / SECOND
        now = time.monotonic()
        if now - self.passed_at < 0.6 or length - self.heard < 0.4:
            return
        threshold = speech_threshold(loudness)
        if not self.pending and speech(loudness, threshold, self.heard) < 0.1:
            self.trim(loudness, threshold, length)
            return
        heard = speech(loudness, threshold, self.offset)
        if heard < 1.0:
            return
        self.passed_at, self.heard = now, length
        result = server.transcribe(pcm[int(self.offset * RATE) * 2 :], self.language or "auto", self.prompt())
        if not self.keeps_language(result, heard):
            return
        words = after_repeat(self.settled[: self.start], words_of(result, self.offset))
        agreed = 0
        while agreed < min(len(words), len(self.previous)) and norm(words[agreed][0]) == norm(self.previous[agreed][0]):
            agreed += 1
        # A long stretch they don't agree on settles all but its last few seconds.
        if length - self.offset > 20:
            agreed = max(agreed, sum(1 for word in words if word[2] < length - 4))
        if self.start + agreed > len(self.settled):
            self.settled[self.start :] = words[:agreed]
        self.previous = words
        self.pending = words[resume(words, self.settled[self.start :]) :]
        shown = (text_of(self.settled), text_of(self.pending))
        if shown != self.shown:
            self.shown = shown
            emit("text", settled=shown[0], pending=shown[1])

    def keeps_language(self, result, heard):
        """Whether a pass's words are in a language to keep. Unfixed, the language is fixed
        once a pass hears two seconds of speech; one not allowed turns into the closest that
        is, and the next pass hears it in that."""
        if self.language:
            return True
        code = LANGUAGE_CODES.get(result.get("language", ""), "")
        if self.languages and code not in self.languages:
            self.language = closest_language(code, self.languages)
            return False
        if heard >= 2.0 and code:
            self.language = code
        return True

    def trim(self, loudness, threshold, length):
        """Moves the start of the audio transcribed into a pause going on, once the stretch
        transcribed grows long. Every word before it settled, since nothing's pending and no
        one spoke since the last pass."""
        recent = loudness[-10:]
        if length - self.offset >= 12 and self.previous and len(recent) == 10 and max(recent) <= threshold:
            self.offset = length - 0.15
            self.start = len(self.settled)
            self.previous = []

    def finish(self, server, debug):
        """The text of the recording, from one pass over all of it."""
        pcm, loudness = self.recorder.snapshot()
        if speech(loudness, speech_threshold(loudness), 0) < 0.3:
            return ""
        language = self.language or "auto"
        result = server.transcribe(pcm, language, self.vocabulary)
        code = LANGUAGE_CODES.get(result.get("language", ""), "")
        if language == "auto" and self.languages and code not in self.languages:
            language = closest_language(code, self.languages)
            result = server.transcribe(pcm, language, self.vocabulary)
        text = text_of(words_of(result, 0))
        # The last recording and recent texts, to look into misheard words.
        (debug / "last.wav").write_bytes(wav(pcm))
        history = debug / "log"
        lines = history.read_text().splitlines()[-49:] if history.exists() else []
        lines.append(f"{time.strftime('%T')} lang={language} detected={code or '-'} text={text}")
        history.write_text("\n".join(lines) + "\n")
        return text


def read_commands(commands):
    for line in sys.stdin:
        try:
            commands.put(json.loads(line))
        except ValueError:
            continue
    # Speshell went away.
    commands.put(None)


def serve():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    # The last recording, the server's output, and recent texts, in the user's own runtime
    # directory, never a shared one such as /tmp.
    debug = Path(os.environ["XDG_RUNTIME_DIR"]) / "speshell"
    debug.mkdir(mode=0o700, exist_ok=True)
    debug /= "dictation"
    debug.mkdir(exist_ok=True)
    commands = queue.Queue()
    threading.Thread(target=read_commands, args=(commands,), daemon=True).start()
    server = Server(debug / "server.log")
    session = None
    try:
        while True:
            try:
                command = commands.get(timeout=0.05) if session else commands.get()
            except queue.Empty:
                command = {}
            if command is None:
                return
            kind = command.get("cmd")
            if kind == "start" and session is None:
                model = command.get("model") or ""
                server.prepare(Path(os.path.expanduser(model)) if model else DEFAULT_MODEL)
                session = Session(command.get("languages") or [], command.get("vocabulary") or "")
            elif kind == "stop" and session:
                session.recorder.stop()
                session.stopping = True
            elif kind == "cancel" and session:
                session.recorder.stop()
                session = None
            if session is None:
                continue
            server.update()
            try:
                if server.state == "failed":
                    raise Failure(server.error)
                if session.recorder.failed():
                    raise Failure("Couldn't record the microphone.")
                if server.state != "ready":
                    continue
                if not session.listening:
                    session.listening = True
                    emit("status", status="listening")
                if session.stopping:
                    emit("final", text=session.finish(server, debug))
                    session = None
                else:
                    session.step(server)
            except (Failure, OSError, ValueError) as error:
                emit("error", message=str(error) if isinstance(error, Failure) else f"Transcription failed: {error}")
                session.recorder.stop()
                session = None
    finally:
        if session:
            session.recorder.stop()
        server.stop()


def keycodes_safe(chars):
    """Whether the distinct characters chars, in order, are safe to type in one go. wtype
    gives the Nth distinct character of its input keycode N. Chromium and Electron apps
    read letters and digits by their symbol, but anything else by its keycode: a space,
    comma or "é" on 14 acts as Backspace, and whatever lands on 29 (Left Ctrl) is dropped,
    e.g. every "ç" of a long text."""
    return len(chars) <= 28 and (len(chars) < 14 or chars[13].isascii() and chars[13].isalnum())


def runs(text):
    """text in runs of words whose keycodes are safe, each word followed by a space."""
    found, run, chars = [], "", ""
    for word in text.split():
        grown = chars + "".join(c for c in dict.fromkeys(word + " ") if c not in chars)
        if run and not keycodes_safe(grown):
            found.append(run)
            run, grown = "", "".join(dict.fromkeys(word + " "))
        run, chars = run + word + " ", grown
    return found + [run] if run else found


def type_text(text):
    for run in runs(text):
        # Through stdin, so a leading "-" isn't read as an option.
        if subprocess.run(["wtype", "-"], input=run.encode(), stderr=subprocess.DEVNULL).returncode != 0:
            return 1
    return 0


def main():
    if sys.argv[1:] == ["serve"]:
        serve()
    elif sys.argv[1:] == ["type"]:
        sys.exit(type_text(sys.stdin.read()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
