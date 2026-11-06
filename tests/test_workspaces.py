"""Exercise workspace scripts against a private tmux server, never live sessions."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class WorkspaceScriptsTest(unittest.TestCase):
    def setUp(self):
        for command in ("tmux", "git", "bash"):
            if shutil.which(command) is None:
                self.skipTest(f"{command} is required")
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-workspaces-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.tmux_binary = shutil.which("tmux")
        self.bash = shutil.which("bash")
        self.env = os.environ.copy()
        self.env.pop("TMUX", None)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        wrapper = bin_dir / "tmux"
        wrapper.write_text(
            f"#!/bin/sh\nexec {shlex.quote(self.tmux_binary)} "
            f"-S {shlex.quote(self.socket)} \"$@\"\n"
        )
        wrapper.chmod(0o755)
        self.env["PATH"] = str(bin_dir) + os.pathsep + self.env["PATH"]
        self.addCleanup(self.stop_server)
        self.repo_a = self.root / "repo one"
        self.repo_b = self.root / "repo two"
        for repo in (self.repo_a, self.repo_b):
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
        self.a1 = self.tmux(
            "-f", "/dev/null", "new-session", "-d", "-s", "test",
            "-P", "-F", "#{window_id}", "-c", str(self.repo_a), "/bin/sh",
        )
        self.b = self.new_window(self.repo_b)
        self.no_repo = self.new_window(self.root)
        self.a2 = self.new_window(self.repo_a)
        self.script("sync.sh")

    def stop_server(self):
        subprocess.run(
            [self.tmux_binary, "-S", self.socket, "kill-server"],
            capture_output=True,
        )

    def tmux(self, *args):
        return subprocess.run(
            [self.tmux_binary, "-S", self.socket, *args],
            env=self.env, check=True, text=True, capture_output=True, timeout=15,
        ).stdout.strip()

    def new_window(self, directory):
        return self.tmux(
            "new-window", "-P", "-F", "#{window_id}", "-c", str(directory),
            "/bin/sh",
        )

    def script(self, name, *args):
        return subprocess.run(
            [self.bash, str(ROOT / "scripts" / name), *args],
            env=self.env, check=True, text=True, capture_output=True, timeout=15,
        ).stdout

    def window_option(self, window, name):
        return self.tmux("show-option", "-wqv", "-t", window, name)

    def active_window(self):
        return self.tmux("display-message", "-p", "#{window_id}")

    def test_sync_layout_and_filter(self):
        self.assertEqual(self.window_option(self.a1, "@workspace"), str(self.repo_a))
        self.assertEqual(self.window_option(self.b, "@workspace"), str(self.repo_b))
        self.assertEqual(self.window_option(self.no_repo, "@workspace"), "(no repo)")
        for _ in range(2):
            self.script("sync.sh")
            self.assertEqual(self.window_option(self.a1, "@workspace-pos"), "first")
            self.assertEqual(self.window_option(self.a2, "@workspace-pos"), "last")
            self.assertEqual(self.window_option(self.a2, "@workspace-slot"), "1")
            self.assertEqual(self.window_option(self.a1, "@workspace-nextact"), "1")
        self.script("toggle.sh")
        self.assertEqual(self.window_option(self.a2, "@workspace-slot"), "3")
        self.script("toggle.sh")
        self.assertEqual(self.window_option(self.a2, "@workspace-slot"), "1")

    def test_new_window_has_rounded_layout_before_first_redraw(self):
        self.script("../tmux-git-workspaces.tmux")
        hooks = self.tmux("show-hooks", "-g", "session-window-changed")
        self.assertNotIn("scripts/sync.sh", hooks)
        self.assertIn("run-shell -b", hooks)
        created = self.new_window(self.repo_a)
        self.assertEqual(self.window_option(created, "@workspace"), str(self.repo_a))
        self.assertIn(self.window_option(created, "@workspace-pos"),
                      ("first", "mid", "last", "only"))
        self.assertNotEqual(self.window_option(created, "@workspace-slot"), "")

    def test_periodic_refresh_detects_repo_at_same_path(self):
        new_repo = self.root / "new repo"
        new_repo.mkdir()
        window = self.new_window(new_repo)
        self.script("sync.sh")
        self.assertEqual(self.window_option(window, "@workspace"), "(no repo)")
        subprocess.run(["git", "init", "-q", str(new_repo)], check=True)
        self.script("sync.sh", "test", "--refresh")
        self.assertEqual(self.window_option(window, "@workspace"), str(new_repo))

    def test_picker_groups_windows_by_repo(self):
        rows = self.script("list.sh").splitlines()
        ids = [row.split("\t")[0] for row in rows]
        self.assertEqual(ids, [self.a1, self.a1, self.a2, self.b, self.b,
                               self.no_repo, self.no_repo])

    def test_navigation_and_workspace_memory(self):
        self.tmux("select-window", "-t", self.a1)
        for target in (self.a2, self.b, self.no_repo, self.a1):
            self.script("step.sh", "next")
            self.assertEqual(self.active_window(), target)
        self.script("step.sh", "prev")
        self.assertEqual(self.active_window(), self.no_repo)
        self.tmux("select-window", "-t", self.a2)
        self.script("sync.sh")
        self.script("step.sh", "next-ws")
        self.assertEqual(self.active_window(), self.b)
        self.script("sync.sh")
        self.script("step.sh", "prev-ws")
        self.assertEqual(self.active_window(), self.a2)


if __name__ == "__main__":
    unittest.main()
