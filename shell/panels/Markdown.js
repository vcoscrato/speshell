.pragma library

// A note's Markdown as the Notes panel renders it: a little TeX (sub- and superscripts,
// Greek letters, and common symbols) written as text, and room between paragraphs.
// Code, in fences or inline, and links stay as typed.

const symbols = {
    alpha: "α", beta: "β", gamma: "γ", delta: "δ", pi: "π", theta: "θ", lambda: "λ", sigma: "σ",
    sum: "∑", int: "∫", infty: "∞", approx: "≈", neq: "≠", le: "≤", ge: "≥", times: "×", div: "÷", pm: "±"
};

// Inline code, an autolink, a link's target, or a bare URL.
const verbatim = /(`+)[\s\S]*?\1|<[^\s>]+>|\]\([^)]*\)|\b(?:https?:\/\/|www\.)[^\s<>()[\]]+/g;

const fence = /^\s*(```|~~~)/;

function texified(text) {
    return text
        // $X_1$, $X_{12}$, $X^2$, and $X^{12}$
        .replace(/\$([a-zA-Z0-9]+)_\{?([a-zA-Z0-9+\-=]+)\}?\$/g, "$1<sub>$2</sub>")
        .replace(/\$([a-zA-Z0-9]+)\^\{?([a-zA-Z0-9+\-=]+)\}?\$/g, "$1<sup>$2</sup>")
        // X_1 and X^2 outside formulas
        .replace(/\b([a-zA-Z])_([0-9a-zA-Z])\b/g, "$1<sub>$2</sub>")
        .replace(/\b([a-zA-Z])\^([0-9a-zA-Z])\b/g, "$1<sup>$2</sup>")
        .replace(/\\([a-z]+)\b/g, (match, name) => symbols[name] ?? match)
        .replace(/\\sqrt\{([^}]+)\}/g, "√($1)");
}

// A line outside a fence, texified between its code spans and links.
function texifiedLine(line) {
    let out = "";
    let last = 0;
    verbatim.lastIndex = 0;
    for (let match = verbatim.exec(line); match !== null; match = verbatim.exec(line)) {
        out += texified(line.substring(last, match.index)) + match[0];
        last = verbatim.lastIndex;
    }
    return out + texified(line.substring(last));
}

// Qt leaves almost no room between Markdown paragraphs. A short spacer paragraph,
// `spacerPx` tall, goes between two plain ones; lists, quotes, headings, tables, and
// code keep their own structure.
function spaceParagraphs(lines, spacerPx) {
    const structural = /^\s*([-*+]\s|\d+[.)]\s|#|>|\||```|~~~)|^\s{4}/;
    const out = [];
    let inFence = false;
    let previous = "";
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (fence.test(line))
            inFence = !inFence;
        if (inFence || line.trim() !== "") {
            out.push(line);
            previous = line;
            continue;
        }
        let next = i + 1;
        while (next < lines.length && lines[next].trim() === "")
            next++;
        const between = previous.trim() !== "" && next < lines.length
            && !structural.test(previous) && !structural.test(lines[next]);
        out.push(between ? "\n<span style='font-size:" + spacerPx + "px'>&nbsp;</span>\n" : "");
        i = next - 1;
        previous = "";
    }
    return out.join("\n");
}

// The Markdown to show for `source`; "" when it is blank.
function render(source, spacerPx) {
    if (source.trim() === "")
        return "";
    let inFence = false;
    const lines = source.split("\n").map(line => {
        if (fence.test(line)) {
            inFence = !inFence;
            return line;
        }
        return inFence ? line : texifiedLine(line);
    });
    return spaceParagraphs(lines, spacerPx);
}
