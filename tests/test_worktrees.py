"""Worktrees share their repository's workspace (real git, isolated tmux server)."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}


class WorktreeTest(unittest.TestCase):
    def setUp(self):
        for command in ("tmux", "git", "bash"):
            if shutil.which(command) is None:
                self.skipTest(f"{command} is required")
        self.temp = tempfile.TemporaryDirectory(prefix="ws-worktrees-")
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name).resolve()
        self.socket = str(self.dir / "socket")
        self.binary = shutil.which("tmux")
        self.env = {**os.environ, **GIT_ENV}
        self.env.pop("TMUX", None)
        bindir = self.dir / "bin"
        bindir.mkdir()
        wrapper = bindir / "tmux"
        wrapper.write_text(f"#!/bin/sh\nexec {shlex.quote(self.binary)} "
                           f"-S {shlex.quote(self.socket)} \"$@\"\n")
        wrapper.chmod(0o755)
        self.env["PATH"] = str(bindir) + os.pathsep + self.env["PATH"]
        self.addCleanup(lambda: subprocess.run(
            [self.binary, "-S", self.socket, "kill-server"], capture_output=True))

    def git(self, *args):
        subprocess.run(["git", *args], env=self.env, check=True, capture_output=True)

    def tmux(self, *args):
        return subprocess.run([self.binary, "-S", self.socket, *args], env=self.env,
                              check=True, text=True, capture_output=True, timeout=15).stdout

    def repo(self, path):
        path.mkdir(parents=True)
        self.git("init", "-q", "-b", "main", str(path))
        self.git("-C", str(path), "commit", "-q", "--allow-empty", "-m", "init")
        return path

    def start(self, directories):
        self.tmux("-f", "/dev/null", "new-session", "-d", "-s", "t", "-n", "w0",
                  "-c", str(directories[0]))
        for i, d in enumerate(directories[1:], 1):
            self.tmux("new-window", "-n", f"w{i}", "-c", str(d))
        self.tmux("set-option", "-g", "@workspaces-key", "off")
        self.tmux("set-option", "-g", "@workspaces-last-key", "off")
        subprocess.run(["bash", str(ROOT / "tmux-git-workspaces.tmux")], env=self.env,
                       check=True, capture_output=True, timeout=30)
        time.sleep(0.5)
        subprocess.run(["bash", str(ROOT / "scripts/sync.sh"), "", "--refresh"],
                       env=self.env, check=True, capture_output=True, timeout=30)

    def tags(self, name):
        return self.tmux("list-windows", "-F", "#{" + name + "}").split("\n")[:-1]

    def test_worktree_windows_share_the_repository_workspace(self):
        main = self.repo(self.dir / "acme" / "api")
        self.git("-C", str(main), "worktree", "add", "-q", "-b", "feat",
                 str(main / ".worktrees" / "feat"))
        self.start([main, main / ".worktrees" / "feat"])
        self.assertEqual(self.tags("@workspace"), [str(main)] * 2)
        self.assertEqual(self.tags("@worktree"), [str(main), str(main / ".worktrees" / "feat")])
        self.assertEqual(self.tags("@workspace-label"), ["api", "api"])

    def test_bare_repository_worktrees_share_one_workspace(self):
        source = self.repo(self.dir / "src")
        bare = self.dir / "bare" / "repo.git"
        bare.parent.mkdir()
        self.git("clone", "-q", "--bare", str(source), str(bare))
        for name in ("dev", "m2"):
            self.git("-C", str(bare), "worktree", "add", "-q", "-b", name,
                     str(self.dir / "bare" / name))
        self.start([self.dir / "bare" / "dev", self.dir / "bare" / "m2"])
        self.assertEqual(self.tags("@workspace"), [str(bare)] * 2)
        self.assertEqual(self.tags("@workspace-label"), ["repo", "repo"])

    def test_same_name_in_different_places_is_qualified(self):
        first = self.repo(self.dir / "acme" / "api")
        second = self.repo(self.dir / "other" / "api")
        self.start([first, second])
        self.assertEqual(self.tags("@workspace-label"), ["acme/api", "other/api"])

    def test_windows_outside_git_stay_in_no_repo(self):
        plain = self.dir / "plain"
        plain.mkdir()
        self.start([plain])
        self.assertEqual(self.tags("@workspace"), ["(no repo)"])
        self.assertEqual(self.tags("@workspace-label"), ["(no repo)"])

    def test_scope_worktree_gives_each_checkout_its_own_run_of_tabs(self):
        main = self.repo(self.dir / "acme" / "api")
        self.git("-C", str(main), "worktree", "add", "-q", "-b", "feat",
                 str(main / ".worktrees" / "feat"))
        self.tmux("-f", "/dev/null", "start-server")
        self.start([main, main / ".worktrees" / "feat"])
        self.assertEqual(self.tags("@workspace-slot"), ["0", "1"])
        self.tmux("set-option", "-g", "@workspaces-scope", "worktree")
        subprocess.run(["bash", str(ROOT / "scripts/layout.sh")], env=self.env,
                       check=True, capture_output=True, timeout=30)
        self.assertEqual(self.tags("@workspace-slot"), ["0", "0"])


if __name__ == "__main__":
    unittest.main()
