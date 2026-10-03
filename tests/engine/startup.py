#!/usr/bin/env python3
# Copyright (C) 2026 Orxooo
# SPDX-License-Identifier: GPL-3.0-only
"""Linked native loader and Electron readiness regressions; synthetic apps only."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path.home() / 'Library/Caches/claudefont/engine-tests'
CACHE.mkdir(parents=True, exist_ok=True)
BINARY = Path(os.environ.get('CLAUDEFONT_TEST_BIN', str(CACHE / 'claudefont')))

def command(args, **kwargs):
    return subprocess.run(args, capture_output=True, text=True, **kwargs)

def sign(path, entitlements=None, runtime=False):
    args = ['codesign', '--force', '--sign', '-']
    if runtime: args += ['--options', 'runtime']
    if entitlements: args += ['--entitlements', str(entitlements)]
    command(args + [str(path)], check=True)

def snapshot(app):
    return {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in app.rglob('*') if p.is_file()}

def fixture(work, electron=False):
    app = work / 'Loader.app'
    for name in ['MacOS', 'Frameworks', 'Resources']:
        (app / 'Contents' / name).mkdir(parents=True)
    library = app / 'Contents/Frameworks/Loader.dylib'
    if electron:
        framework = app / 'Contents/Frameworks/Electron Framework.framework'
        (framework / 'Versions/A/Resources').mkdir(parents=True)
        library = framework / 'Versions/A/Electron Framework'
        (framework / 'Versions/Current').symlink_to('A')
        (framework / 'Electron Framework').symlink_to('Versions/Current/Electron Framework')
        (framework / 'Resources').symlink_to('Versions/Current/Resources')
        (framework / 'Resources/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'io.github.orxooo.claudefont.loader',
            'CFBundleExecutable': 'Electron Framework', 'CFBundlePackageType': 'FMWK'}))
    lib_source = work / 'library.c'
    lib_source.write_text('int loaded(void) { return 42; }')
    install_name = '@executable_path/../Frameworks/' + (
        'Electron Framework.framework/Electron Framework' if electron else 'Loader.dylib')
    command(['xcrun', 'clang', '-dynamiclib', str(lib_source), '-install_name',
             install_name, '-o', str(library)], check=True)
    sign(framework if electron else library)
    source = work / 'main.c'
    source.write_text('#include <unistd.h>\n#include <stdio.h>\n#include <stdlib.h>\n'
                      '#include <string.h>\n#include <signal.h>\n'
                      'extern int loaded(void);\nint main(int argc,char **argv) {\n'
                      'if(loaded()!=42)return 7; fprintf(stderr,"linked library loaded\\n");'
                      'fflush(stderr); char *mode=getenv("CLAUDEFONT_FIXTURE_RENDERER_MODE");'
                      'if(mode){char path[4096];snprintf(path,sizeof(path),"%s",argv[0]);'
                      'char *tail=strstr(path,"/Contents/MacOS/");if(!tail)return 8;'
                      'strcpy(tail,"/Contents/Frameworks/Loader (Renderer)");signal(SIGCHLD,SIG_IGN);'
                      'for(int i=0;i<100;i++){if(fork()==0){execl(path,path,mode,NULL);_exit(9);}'
                      'if(strcmp(mode,"persistent")==0)break;usleep(400000);}}'
                      'sleep(40); return 0; }')
    command(['xcrun', 'clang', str(source), str(library), '-o',
             str(app / 'Contents/MacOS/Loader')], check=True)
    if electron:
        helper_source = work / 'helper.c'
        helper_source.write_text('#include <unistd.h>\n#include <string.h>\n'
                                 'int main(int argc,char **argv){int p=getppid();'
                                 'int n=argc>1&&!strcmp(argv[1],"rotate")?8:400;'
                                 'for(int i=0;i<n&&getppid()==p;i++)usleep(100000);return 0;}')
        helper = app / 'Contents/Frameworks/Loader (Renderer)'
        command(['xcrun', 'clang', str(helper_source), '-o', str(helper)], check=True)
        sign(helper)
    files = {'package.json': b'{"main":"main.js"}', 'main.js': b'// main\n',
             '.vite/build/mainView.js': b'const {ipcRenderer}=require("electron");\n'}
    header = {'files': {}}
    payload = bytearray()
    for path, data in files.items():
        node = header
        parts = path.split('/')
        for part in parts[:-1]: node = node['files'].setdefault(part, {'files': {}})
        node['files'][parts[-1]] = {'offset': str(len(payload)), 'size': len(data)}
        payload.extend(data)
    raw = json.dumps(header, separators=(',', ':')).encode()
    aligned = (len(raw) + 3) // 4 * 4
    (app / 'Contents/Resources/app.asar').write_bytes(
        struct.pack('<4I', 4, aligned + 8, aligned + 4, len(raw)) + raw +
        b'\0' * (aligned - len(raw)) + payload)
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': 'com.anthropic.claudefordesktop',
        'CFBundleExecutable': 'Loader', 'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': 'loader-1',
        'ElectronAsarIntegrity': {'Resources/app.asar': {
            'algorithm': 'SHA256', 'hash': hashlib.sha256(raw).hexdigest()}}}))
    sign(app, runtime=True)
    return app

with tempfile.TemporaryDirectory(prefix='loader-', dir=CACHE) as directory:
    work = Path(directory)
    app = fixture(work)
    failed = command([str(app / 'Contents/MacOS/Loader')], timeout=15)
    assert failed.returncode != 0 and 'linked library loaded' not in failed.stderr, failed.stderr
    print('PASS: hardened linked fixture reproduces dyld rejection', flush=True)
    library_before = (app / 'Contents/Frameworks/Loader.dylib').read_bytes()
    env = dict(os.environ, CLAUDEFONT_DATA_DIR=str(work / 'state'),
               CLAUDEFONT_CONFIG=str(work / 'config.json'))
    installed = command([str(BINARY), 'install', '--app', str(app), '-y'], env=env, timeout=60)
    assert installed.returncode == 0, installed.stdout + installed.stderr
    child = subprocess.Popen([str(app / 'Contents/MacOS/Loader')], stderr=subprocess.PIPE, text=True)
    try:
        assert child.stderr.readline().strip() == 'linked library loaded'
    finally:
        child.terminate()
        child.wait(timeout=5)
    assert (app / 'Contents/Frameworks/Loader.dylib').read_bytes() == library_before
    print('PASS: applying loads the linked library without changing nested code', flush=True)

    # A live main process alone does not prove that Electron started a renderer.
    waiting_work = work / 'waiting'
    waiting_work.mkdir()
    waiting = fixture(waiting_work, electron=True)
    entitlements = work / 'entitlements.plist'
    entitlements.write_bytes(plistlib.dumps({'com.apple.security.cs.disable-library-validation': True}))
    sign(waiting, entitlements, runtime=True)
    before = snapshot(waiting)
    rejected = command([str(BINARY), 'install', '--app', str(waiting), '-y'],
                       env=dict(env, CLAUDEFONT_DATA_DIR=str(work / 'waiting-state')), timeout=60)
    assert rejected.returncode != 0 and 'renderer' in rejected.stderr.lower(), rejected.stdout + rejected.stderr
    assert snapshot(waiting) == before
    print('PASS: no Electron renderer rejects success and restores the complete app', flush=True)
    accepted = command([str(BINARY), 'install', '--app', str(waiting), '-y'],
                       env=dict(env, CLAUDEFONT_DATA_DIR=str(work / 'waiting-state'),
                                CLAUDEFONT_FIXTURE_RENDERER_MODE='persistent'), timeout=60)
    assert accepted.returncode == 0, accepted.stdout + accepted.stderr
    print('PASS: an owned persistent renderer permits startup', flush=True)

    rotating_work = work / 'rotating'
    rotating_work.mkdir()
    rotating = fixture(rotating_work, electron=True)
    sign(rotating, entitlements, runtime=True)
    before = snapshot(rotating)
    rejected = command([str(BINARY), 'install', '--app', str(rotating), '-y'],
                       env=dict(env, CLAUDEFONT_DATA_DIR=str(work / 'rotating-state'),
                                CLAUDEFONT_FIXTURE_RENDERER_MODE='rotate'), timeout=60)
    assert rejected.returncode != 0 and 'renderer' in rejected.stderr.lower(), rejected.stdout + rejected.stderr
    assert snapshot(rotating) == before
    print('PASS: overlapping short-lived renderers cannot bypass rollback', flush=True)

    wrapped_work = work / 'wrapped'
    wrapped_work.mkdir()
    wrapped = fixture(wrapped_work)
    plist = wrapped / 'Contents/Info.plist'
    info = plistlib.loads(plist.read_bytes())
    info.update(CFBundleIdentifier='io.github.orxooo.claudefont.test',
                ClaudefontRuntimeExecutable='Loader', CFBundleExecutable='Wrapper')
    plist.write_bytes(plistlib.dumps(info))
    wrapper_source = wrapped_work / 'wrapper.c'
    wrapper_source.write_text('int main(void){return 0;}')
    command(['xcrun','clang',str(wrapper_source),'-o',str(wrapped / 'Contents/MacOS/Wrapper')],check=True)
    sign(wrapped / 'Contents/MacOS/Loader', runtime=True)
    sign(wrapped, runtime=True)
    applied = command([str(BINARY),'install','--app',str(wrapped),'-y'],
                      env=dict(env,CLAUDEFONT_DATA_DIR=str(work / 'wrapped-state')),timeout=60)
    assert applied.returncode == 0, applied.stdout + applied.stderr
    print('PASS: test launcher and its separate native runtime are both signed for retained libraries',flush=True)
