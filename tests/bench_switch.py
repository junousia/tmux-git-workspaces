"""Compare v0.7.2 with the working tree on isolated, single-core tmux servers.

Requires a sibling tmux-axolotl checkout with v0.7.1 and the tmux-git-workspaces
v0.7.2 tag. No live sessions or installed plugins are touched.
"""

import io, os, pathlib, shutil, statistics, subprocess, tarfile, tempfile, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
THEME=ROOT.parent/'tmux-axolotl'
BASH=shutil.which('bash')
REAL=shutil.which('tmux')
# Keep the server and clients on one core to expose scheduling contention.
if hasattr(os, 'sched_setaffinity'):
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})

def archive(repo,rev,dest):
    payload=subprocess.check_output(['git','-C',str(repo),'archive',rev])
    with tarfile.open(fileobj=io.BytesIO(payload)) as tar: tar.extractall(dest)

def pct(xs,p): return sorted(xs)[round((len(xs)-1)*p)]*1000

def run_case(old, mode):
    with tempfile.TemporaryDirectory(prefix='tmux-bench-') as tmp:
        base=pathlib.Path(tmp); sock=base/'sock'; wrapper=base/'bin';wrapper.mkdir()
        (wrapper/'tmux').write_text(f'#!/bin/sh\nexec {REAL} -S {sock} "$@"\n');(wrapper/'tmux').chmod(0o755)
        env=os.environ.copy();env.pop('TMUX',None);env['PATH']=str(wrapper)+os.pathsep+env['PATH']
        def tm(*args): return subprocess.check_output([REAL,'-S',str(sock),*args],env=env,text=True,stderr=subprocess.DEVNULL).strip()
        work=ROOT; theme=THEME
        if old:
            work=base/'work';theme=base/'theme';work.mkdir();theme.mkdir();archive(ROOT,'v0.7.2',work);archive(THEME,'v0.7.1',theme)
        repos=[]
        for i in range(3):
            repo=base/f'repo{i}';subprocess.run(['git','init','-q',str(repo)],check=True);repos.append(repo)
        ids=[]
        try:
            ids.append(tm('-f','/dev/null','new-session','-d','-s','bench','-n','fish','-P','-F','#{window_id}','-c',str(repos[0]),'/bin/sh'))
            for i in range(1,12): ids.append(tm('new-window','-n','fish','-P','-F','#{window_id}','-c',str(repos[i//4]),'/bin/sh'))
            tm('set-option','-g','@axolotl-scheme','kanagawa-dragon');tm('set-option','-g','@axolotl-scheme-key','off')
            subprocess.run([BASH,str(theme/'tmux-axolotl.tmux')],env=env,check=True,capture_output=True)
            subprocess.run([BASH,str(work/'tmux-git-workspaces.tmux')],env=env,check=True,capture_output=True)
            subprocess.run([BASH,str(work/'scripts/sync.sh')],env=env,check=True,capture_output=True)
            tm('select-window','-t',ids[0]);time.sleep(.2)
            times=[]
            for n in range(42):
                target=ids[(n+1)%len(ids)]
                begin=time.perf_counter()
                if mode=='direct': tm('select-window','-t',target)
                else: tm('run-shell',str(work/'scripts/step.sh')+' next')
                times.append(time.perf_counter()-begin)
            print(('old' if old else 'new'),mode,'median_ms',round(pct(times[4:],.5),2),'p95_ms',round(pct(times[4:],.95),2),'max_ms',round(max(times[4:])*1000,2),flush=True)
        finally:
            subprocess.run([REAL,'-S',str(sock),'kill-server'],env=env,capture_output=True)

if not (THEME/'tmux-axolotl.tmux').exists():
    raise SystemExit('A tmux-axolotl checkout is required beside this repository')
for mode in ('direct','step'):
    for old in (True,False): run_case(old,mode)
