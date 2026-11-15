"""speshell-system's reading of the modules, its edits, and its plan, in a scratch home."""

import importlib.machinery
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

SCRATCH = tempfile.TemporaryDirectory()
HOME = Path(SCRATCH.name)
os.environ.update(HOME=str(HOME), XDG_CONFIG_HOME=str(HOME / ".config"), XDG_DATA_HOME=str(HOME / ".local/share"))
ENGINE = Path(__file__).resolve().parent.parent / "shell/system/speshell-system"
loader = importlib.machinery.SourceFileLoader("speshell_system", str(ENGINE))
system = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(system)
SYSTEM = HOME / ".config/speshell/system"
# This machine's module, named after it as a hostname would be written.
MACHINE = system.HOST.capitalize()


class Installed:
    def __init__(self, needed_by=()):
        self.needed_by = list(needed_by)

    def compute_requiredby(self):
        return self.needed_by


class Machine:
    """pacman's database as the plan reads it."""

    def __init__(self, explicit=(), dependencies=(), needed_by=None):
        needed_by = needed_by or {}
        self.installed = {name: Installed(needed_by.get(name, ())) for name in [*explicit, *dependencies]}
        self.explicit = set(explicit)


def write(path, text):
    path = SYSTEM / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class SystemTest(unittest.TestCase):
    def setUp(self):
        for path in sorted(HOME.rglob("*"), reverse=True):
            path.unlink() if path.is_file() or path.is_symlink() else path.rmdir()
        write(f"{MACHINE}.conf", "use base desk  # mine\n")
        write("base.conf", "")
        write("desk.conf", "")

    def plan(self, machine, state=None):
        return system.Plan(system.Config().require(), machine, {**system.load_state(), **(state or {})})


class Reading(SystemTest):
    def test_every_kind_of_line(self):
        write(
            "base.conf",
            "\n".join(
                [
                    "git  # the one",
                    "file",
                    "",
                    "service sshd",
                    "user-service theme@%u.path",
                    "group docker",
                    "linger",
                    "file /etc/x.conf x.conf 600",
                    "on /etc/x*: reload x",
                    "run make it so",
                    "",
                ]
            ),
        )
        write("files/base/x.conf", "x")
        base = system.Config().require().modules["base"]
        self.assertEqual(base.packages, ["git", "file"])
        self.assertEqual(base.services, [("system", "sshd"), ("user", f"theme@{system.USER}.path")])
        self.assertEqual(
            (base.groups, base.linger, base.triggers, base.runs),
            (["docker"], True, [("/etc/x*", "reload x")], ["make it so"]),
        )
        self.assertEqual(base.files, [("/etc/x.conf", base.dir / "x.conf", "600", 8)])

    def test_file_lines_name_their_file_or_take_the_path_s(self):
        write("base.conf", "file ~/.bashrc\nfile ~/.config/app\nfile /etc/one.conf shared\nfile /etc/two.conf shared\n")
        for name in ("bashrc", "app/a", "app/sub/b", "shared"):
            write(f"files/base/{name}", name)
        base = system.Config().require().modules["base"]
        self.assertEqual(
            [(target, str(source.relative_to(base.dir))) for target, source, _, _ in base.files],
            [
                (str(HOME / ".bashrc"), "bashrc"),
                (str(HOME / ".config/app/a"), "app/a"),
                (str(HOME / ".config/app/sub/b"), "app/sub/b"),
                ("/etc/one.conf", "shared"),
                ("/etc/two.conf", "shared"),
            ],
        )

    def test_problems_name_their_file_and_line(self):
        write(
            "base.conf",
            "\n".join(
                [
                    "git",
                    "service two units",
                    "file ~/.missing",
                    f"file {HOME}/.bashrc",
                    "file ~/.bashrc 600",
                    "file /etc/x ../desk.conf",
                    "use gone",
                    "",
                ]
            ),
        )
        write("files/base/bashrc", "")
        problems = sorted((p.file, p.line) for p in system.Config().problems)
        self.assertEqual(problems, [("base.conf", line) for line in (2, 3, 4, 5, 6, 7)])

    def test_the_machine_brings_in_what_it_uses_and_theirs(self):
        write("desk.conf", "use extra\n")
        write("extra.conf", "")
        write("spare.conf", "")
        config = system.Config()
        self.assertEqual(config.on, ["base", "extra", "desk", MACHINE])
        self.assertEqual(config.via["extra"], "desk")

    def test_a_module_that_brings_itself_in_is_a_problem(self):
        write("base.conf", "use desk\n")
        write("desk.conf", "use base\n")
        self.assertEqual(len(system.Config().problems), 1)


class Editing(SystemTest):
    def test_add_goes_after_the_last_package(self):
        conf = write("base.conf", "git  # note\n\nnano\nlinger\nservice sshd\n")
        system.add(["base", "vim", "jq"])
        self.assertEqual(conf.read_text(), "git  # note\n\nnano\nvim\njq\nlinger\nservice sshd\n")
        system.add(["desk", "steam"])
        self.assertEqual((SYSTEM / "desk.conf").read_text(), "steam\n")

    def test_add_refuses_a_package_twice(self):
        write("base.conf", "git\n")
        with self.assertRaises(system.Stop):
            system.add(["base", "git"])

    def test_remove_takes_every_line_of_it(self):
        base = write("base.conf", "git\nvim  # editor\nservice sshd\n")
        desk = write("desk.conf", "vim\n")
        system.remove(["vim"])
        self.assertEqual((base.read_text(), desk.read_text()), ("git\nservice sshd\n", ""))

    def test_switch_edits_the_use_lines_keeping_the_comment(self):
        machine = SYSTEM / f"{MACHINE}.conf"
        write("extra.conf", "")
        system.switch("off", ["desk"])
        system.switch("on", ["extra"])
        self.assertEqual(machine.read_text(), "use base extra  # mine\n")
        system.switch("off", ["base"])
        system.switch("off", ["extra"])
        self.assertEqual(machine.read_text(), "")
        system.switch("on", ["base"])
        self.assertEqual(machine.read_text(), "use base\n")

    def test_switch_refuses_what_comes_with_another(self):
        write("base.conf", "use extra\n")
        write("extra.conf", "")
        with self.assertRaises(system.Stop):
            system.switch("off", ["extra"])


class Planning(SystemTest):
    def kinds(self, plan):
        return [(step.kind, step.subject) for step in plan.steps]

    def test_packages(self):
        write("base.conf", "git\nvim\nnew\n")
        machine = Machine(
            explicit=["git", "gone", "kept", "loose"], dependencies=["vim"], needed_by={"kept": ["other"]}
        )
        plan = self.plan(machine, {"packages": ["git", "gone", "kept"]})
        self.assertEqual(
            self.kinds(plan), [("demote", "kept"), ("remove", "gone"), ("install", "new"), ("explicit", "vim")]
        )
        self.assertEqual(plan.undeclared, ["loose"])

    def test_home_files(self):
        write("base.conf", "".join(f"file ~/{name}\n" for name in ("new", "same", "differs", "linked")))
        for name, text in (("new", "a"), ("same", "b"), ("differs", "c"), ("linked", "d")):
            write(f"files/base/{name}", text)
        (HOME / "same").write_text("b")
        (HOME / "differs").write_text("not c")
        (HOME / "linked").symlink_to(SYSTEM / "files/base/linked")
        (HOME / "left").symlink_to(SYSTEM / "files/base/gone")
        plan = self.plan(Machine(), {"files": {str(HOME / "left"): {"module": "base", "kind": "link"}}})
        self.assertEqual(
            self.kinds(plan),
            [("link", str(HOME / "new")), ("link", str(HOME / "same")), ("unlink", str(HOME / "left"))],
        )
        self.assertEqual([step.detail for step in plan.steps[:2]], ["new", "same"])
        self.assertEqual(plan.drift, [("base", str(HOME / "differs"), "changed")])

    def test_an_on_line_hears_every_module_once(self):
        write("base.conf", "file ~/conf/a a\non ~/conf/*: reload\n")
        write("desk.conf", "file ~/conf/b b\n")
        write("files/base/a", "a")
        write("files/desk/b", "b")
        plan = self.plan(Machine())
        self.assertEqual(
            [(s.kind, s.subject, s.detail) for s in plan.steps if s.kind == "trigger"], [("trigger", "reload", "user")]
        )

    def test_a_file_from_two_modules_is_a_problem(self):
        for id in ("base", "desk"):
            write(f"{id}.conf", "file ~/twice\n")
            write(f"files/{id}/twice", id)
        plan = self.plan(Machine())
        self.assertEqual(
            [(p.file, p.line, p.message) for p in plan.problems], [("desk.conf", 1, "~/twice is placed by base too")]
        )

    def test_a_run_line_runs_once_and_again_when_it_changes(self):
        write("base.conf", "run make it\n")
        write("desk.conf", "run make it\n")
        self.assertEqual(self.kinds(self.plan(Machine())), [("run", "make it")])
        self.assertEqual(self.kinds(self.plan(Machine(), {"ran": ["make it"]})), [])
        write("base.conf", "run make it so\n")
        self.assertEqual(self.kinds(self.plan(Machine(), {"ran": ["make it"]})), [("run", "make it so")])


if __name__ == "__main__":
    unittest.main()
