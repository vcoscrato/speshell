"""speshell-system's reading of the modules, its edits, and its plan, in a scratch home."""

import contextlib
import importlib.machinery
import importlib.util
import io
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

    def __init__(self, explicit=(), dependencies=(), needed_by=None, owners=None, cached=(), provides=None, groups=()):
        needed_by = needed_by or {}
        self.provides, self.groups = provides or {}, set(groups)
        self.installed = {name: Installed(needed_by.get(name, ())) for name in [*explicit, *dependencies]}
        self.explicit = set(explicit)
        self.owners, self.cached = owners or {}, set(cached)

    def provider(self, name):
        return name if name in self.installed else self.provides.get(name, "")

    def group(self, name):
        return name in self.groups

    def owner(self, path):
        return self.owners.get(path, "")

    def archive(self, name):
        return f"/var/cache/pacman/pkg/{name}.pkg.tar.zst" if name in self.cached else None


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
        self.assertEqual(base.files, [system.Placed("/etc/x.conf", base.dir / "x.conf", "600", 8, "base")])

    def test_file_lines_name_their_file_or_take_the_path_s(self):
        write("base.conf", "file ~/.bashrc\nfile ~/.config/app\nfile /etc/one.conf shared\nfile /etc/two.conf shared\n")
        for name in ("bashrc", "app/a", "app/sub/b", "shared"):
            write(f"files/base/{name}", name)
        base = system.Config().require().modules["base"]
        self.assertEqual(
            [(placed.target, str(placed.source.relative_to(base.dir))) for placed in base.files],
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

    def test_a_comment_starts_after_a_space_outside_quotes(self):
        for raw, parts in (
            ("# all of it", ("", "all of it")),
            ("git  # the one", ("git", "the one")),
            ("run sed s#a#b#", ("run sed s#a#b#", "")),
            ('run sed "s #a# b"  # gone', ('run sed "s #a# b"', "gone")),
            ("run echo '# kept' #gone", ("run echo '# kept'", "gone")),
        ):
            self.assertEqual(system.split_comment(raw), parts)

    def test_a_directory_places_what_its_links_lead_to_once(self):
        write("base.conf", "file ~/.config/app\n")
        write("shared/b", "b")
        write("files/base/app/a", "a")
        (SYSTEM / "files/base/app/shared").symlink_to(SYSTEM / "shared")
        (SYSTEM / "files/base/app/up").symlink_to(SYSTEM / "files/base/app")
        base = system.Config().require().modules["base"]
        self.assertEqual(
            [placed.target for placed in base.files],
            [str(HOME / ".config/app/a"), str(HOME / ".config/app/shared/b")],
        )


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

    def test_an_edit_keeps_a_linked_module_linked(self):
        kept = HOME / "dotfiles/base.conf"
        kept.parent.mkdir()
        kept.write_text("git\n")
        (SYSTEM / "base.conf").unlink()
        (SYSTEM / "base.conf").symlink_to(kept)
        system.add(["base", "vim"])
        self.assertTrue((SYSTEM / "base.conf").is_symlink())
        self.assertEqual(kept.read_text(), "git\nvim\n")

    def test_adopt_takes_the_home_file_into_its_module(self):
        write("base.conf", "file ~/.bashrc\n")
        source = write("files/base/bashrc", "theirs")
        (HOME / ".bashrc").write_text("mine")
        system.adopt(["~/.bashrc"])
        self.assertEqual(os.readlink(HOME / ".bashrc"), str(source))
        self.assertEqual(source.read_text(), "mine")

    def test_restore_links_again_keeping_the_file_it_replaces(self):
        write("base.conf", "file ~/.bashrc\n")
        source = write("files/base/bashrc", "theirs")
        (HOME / ".bashrc").write_text("mine")
        with contextlib.redirect_stdout(io.StringIO()):
            system.restore(["~/.bashrc"])
        self.assertEqual(os.readlink(HOME / ".bashrc"), str(source))
        self.assertEqual(source.read_text(), "theirs")
        [kept] = (HOME / ".local/share/speshell/system/replaced").glob("*/.bashrc")
        self.assertEqual(kept.read_text(), "mine")

    def test_adopt_refuses_a_link(self):
        write("base.conf", "file ~/.bashrc\n")
        write("files/base/bashrc", "theirs")
        (HOME / ".bashrc").symlink_to(SYSTEM / "files/base/bashrc")
        with self.assertRaises(system.Stop):
            system.adopt(["~/.bashrc"])

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

    def test_a_declared_name_an_installed_package_provides_is_that_package(self):
        write("base.conf", "quickshell\njack\nxorg\n")
        machine = Machine(
            explicit=["quickshell-git"],
            dependencies=["pipewire-jack"],
            provides={"quickshell": "quickshell-git", "jack": "pipewire-jack"},
            groups=["xorg"],
        )
        plan = self.plan(machine)
        self.assertEqual(self.kinds(plan), [("explicit", "pipewire-jack")])
        self.assertEqual(
            (plan.undeclared, [p.message for p in plan.problems]),
            ([], ["xorg is a group, not a package: list its packages"]),
        )

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
        self.assertEqual([step.changes for step in plan.steps[:2]], [True, False])
        self.assertEqual(plan.drift, [("base", str(HOME / "differs"), "changed")])

    def test_a_link_of_yours_stays_and_a_dangling_one_goes(self):
        write("base.conf", "file ~/mine\nfile ~/dangling\n")
        write("files/base/mine", "a")
        write("files/base/dangling", "b")
        (HOME / "dotfiles").mkdir()
        (HOME / "dotfiles/mine").write_text("a")
        (HOME / "mine").symlink_to(HOME / "dotfiles/mine")
        (HOME / "dangling").symlink_to(HOME / "nowhere")
        plan = self.plan(Machine())
        self.assertEqual(self.kinds(plan), [("link", str(HOME / "dangling"))])
        self.assertEqual(plan.drift, [("base", str(HOME / "mine"), "blocked")])

    def test_a_root_copy_keeps_what_it_first_replaces(self):
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        write("base.conf", "".join(f"file {root}/{name}\n" for name in ("new", "there", "recorded", "same")))
        for name in ("new", "there", "recorded", "same"):
            write(f"files/base/{name}", name)
        (root / "there").write_text("before")
        (root / "recorded").write_text("before")
        (root / "same").write_text("same")
        record = {"module": "base", "kind": "copy", "sha": "", "size": 0, "mtime": 0}
        plan = self.plan(Machine(), {"files": {str(root / "recorded"): record}})
        self.assertEqual(
            [(s.kind, s.subject, s.keep) for s in plan.steps],
            [
                ("copy", str(root / "new"), False),
                ("copy", str(root / "there"), True),
                ("copy", str(root / "recorded"), False),
                ("mode", str(root / "same"), True),
            ],
        )

    def test_a_root_copy_whose_line_goes_puts_back_what_was_there(self):
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        for name in ("kept", "owned", "uncached", "plain", "older"):
            (root / name).write_text(name)
        older = {"module": "base", "kind": "copy", "sha": "", "size": 0, "mtime": 0}
        record = {**older, "original": False}
        files = {str(root / name): record for name in ("owned", "uncached", "plain", "gone")}
        files[str(root / "kept")] = {**record, "original": True}
        files[str(root / "older")] = older
        machine = Machine(owners={str(root / "owned"): "one", str(root / "uncached"): "two"}, cached=["one"])
        plan = self.plan(machine, {"files": files})
        self.assertEqual(
            [(s.kind, s.subject) for s in plan.steps],
            [
                ("delete", str(root / "plain")),
                ("restore", str(root / "kept")),
                ("reinstate", str(root / "owned")),
                ("forget", str(root / "older")),
                ("forget", str(root / "uncached")),
            ],
        )
        self.assertTrue(plan.leaves())

    def test_removing_a_package_apply_wouldn_t_remove_is_a_problem(self):
        write("base.conf", "git\n")
        machine = Machine(explicit=["git", "loose"], dependencies=["lib"])
        plan = system.Plan(system.Config().require(), machine, system.load_state(), ["git", "lib", "none", "loose"])
        self.assertEqual(len(plan.problems), 3)
        self.assertEqual(self.kinds(plan), [("remove", "loose")])

    def test_an_on_line_hears_every_module_once(self):
        write("base.conf", "file ~/conf/a a\non ~/conf/*: reload\n")
        write("desk.conf", "file ~/conf/b b\n")
        write("files/base/a", "a")
        write("files/desk/b", "b")
        plan = self.plan(Machine())
        self.assertEqual(
            [(s.kind, s.subject, s.user) for s in plan.steps if s.kind == "trigger"], [("trigger", "reload", True)]
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


class Applying(SystemTest):
    def test_an_apply_stopped_partway_keeps_what_it_placed(self):
        write("base.conf", "file ~/placed\nfile ~/blocked/file\n")
        write("files/base/placed", "a")
        write("files/base/file", "b")
        (HOME / "blocked").write_text("in the way")
        plan = self.plan(Machine())
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
            system.Apply(plan).files()
        self.assertEqual(system.load_state()["files"], {str(HOME / "placed"): {"module": "base", "kind": "link"}})


if __name__ == "__main__":
    unittest.main()
