#!/usr/bin/env python3
# Copyright (C) 2026 Orxooo
# SPDX-License-Identifier: GPL-3.0-only
"""Independent signed fixture tests. Never target an installed application."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(os.environ.get('CLAUDEFONT_TEST_CACHE', str(Path.home()/'Library/Caches/claudefont/engine-tests')))
CACHE.mkdir(parents=True, exist_ok=True)
BINARY = Path(os.environ.get('CLAUDEFONT_TEST_BIN', str(CACHE/'claudefont')))
if 'CLAUDEFONT_TEST_BIN' not in os.environ:
    subprocess.run([str(ROOT/'cli/build.sh'),str(BINARY)],check=True)

def sha(data): return hashlib.sha256(data).hexdigest()
def pack(files, extras=None):
    header={'files':{}}; payload=bytearray()
    for path, content in sorted(files.items()):
        directory=header
        pieces=path.split('/')
        for part in pieces[:-1]: directory=directory['files'].setdefault(part,{'files':{}})
        directory['files'][pieces[-1]]={'offset':str(len(payload)),'size':len(content),
              'integrity':{'algorithm':'SHA256','hash':sha(content),'blockSize':4194304,
                           'blocks':[sha(content[i:i+4194304]) for i in range(0,len(content),4194304)] or [sha(b'')]}}
        payload.extend(content)
    if extras: header['files'].update(extras)
    raw=json.dumps(header,separators=(',',':'),sort_keys=True).encode()
    aligned=(len(raw)+3)//4*4
    return struct.pack('<4I',4,aligned+8,aligned+4,len(raw))+raw+b'\0'*(aligned-len(raw))+payload

def unpack(path):
    data=path.read_bytes(); _,header_size,_,length=struct.unpack('<4I',data[:16]); raw=data[16:16+length]
    result={}
    def visit(node,prefix=''):
        for key,child in node['files'].items():
            name=prefix+key
            if 'files' in child: visit(child,name+'/')
            elif 'offset' in child: result[name]=data[8+header_size+int(child['offset']):8+header_size+int(child['offset'])+child['size']]
    visit(json.loads(raw)); return raw,result

def snapshot(app):
    return {str(p.relative_to(app)):(p.stat().st_mode&0o7777,sha(p.read_bytes()))
            for p in app.rglob('*') if p.is_file() and not p.is_symlink()}

class FixtureDirectory(tempfile.TemporaryDirectory):
    def __exit__(self, exception_type, value, traceback):
        if exception_type is not None:
            self._finalizer.detach()
            print('Failure fixture preserved:',self.name,flush=True)
            return False
        return super().__exit__(exception_type,value,traceback)

count=0
def check(name,condition):
    global count
    if not condition: raise AssertionError(name)
    count+=1; print('PASS:',name,flush=True)

with FixtureDirectory(prefix='run-',dir=CACHE) as directory:
    work=Path(directory).resolve(); app=work/'Fixture.app'; resources=app/'Contents/Resources'
    resources.mkdir(parents=True); (app/'Contents/MacOS').mkdir(); (app/'Contents/Frameworks').mkdir()
    source=work/'fixture.c'
    source.write_text(r'''#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc,char **argv) {
 char path[4096];snprintf(path,sizeof(path),"%s",argv[0]);char *tail=strstr(path,"/Contents/MacOS/");
 if(!tail)return 3;strcpy(tail,"/Contents/Resources/app.asar");
 FILE *file=fopen(path,"rb");if(!file)return 4;fseek(file,0,SEEK_END);long n=ftell(file);rewind(file);
 char *bytes=calloc(n+1,1);fread(bytes,1,n,file);fclose(file);int patched=0;
 for(long i=0;i<n-23;i++){if(!memcmp(bytes+i,"claudefont-renderer-1",20)){patched=1;break;}}free(bytes);
 fprintf(stderr,"fixture patched=%d fail=%d\n",patched,getenv("CLAUDEFONT_FIXTURE_FAIL_PATCH")!=NULL);fflush(stderr);
 if(getenv("CLAUDEFONT_FIXTURE_FAIL_PATCH")&&patched)return 19;
 sleep(20);return 0;
}''')
    subprocess.run(['xcrun','clang',str(source),'-o',str(app/'Contents/MacOS/Fixture')],check=True)
    lib=work/'library.c';lib.write_text('int fixture(void){return 42;}')
    dylib=app/'Contents/Frameworks/Fixture.dylib'
    subprocess.run(['xcrun','clang','-dynamiclib',str(lib),'-o',str(dylib)],check=True)
    subprocess.run(['codesign','--force','--sign','-',str(dylib)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    files={'package.json':b'{"main":"main.js"}','main.js':b'// independent main entry\n',
       '.vite/build/mainView.js':b'const {ipcRenderer}=require("electron");\n//# sourceMappingURL=fixture.map',
       '.vite/renderer/main_window/index.html':b'<html><body>Independent renderer</body></html>',
       '.vite/renderer/main_window/terminal.js':b'// xterm API fixture\nclass Terminal{constructor(options){globalThis.terminalOptions=options;}}\nconst t=new Terminal({allowProposedApi:true,fontSize:16,fontFamily:"monospace",cursorBlink:true});',
       'empty':b'', 'plain.txt':'Original content 字体'.encode()}
    external=resources/'app.asar.unpacked/native.node';external.parent.mkdir()
    subprocess.run(['xcrun','clang','-dynamiclib',str(lib),'-o',str(external)],check=True)
    before_sign=external.read_bytes()
    external_record={'unpacked':True,'size':len(before_sign),'integrity':{'algorithm':'SHA256','hash':sha(before_sign),'blockSize':4194304,'blocks':[sha(before_sign)]}}
    archive=resources/'app.asar';archive.write_bytes(pack(files,{'alias':{'link':'.vite/renderer'},'native.node':external_record}))
    subprocess.run(['codesign','--force','--sign','-',str(external)],check=True,stderr=subprocess.DEVNULL)
    external_signed=external.read_bytes()
    check('native external resource changes after archive packing',len(external_signed)!=len(before_sign) and sha(external_signed)!=sha(before_sign))
    header,_=unpack(archive)
    info={'CFBundleIdentifier':'com.anthropic.claudefordesktop','CFBundleName':'Fixture','CFBundleExecutable':'Fixture',
          'CFBundlePackageType':'APPL','CFBundleShortVersionString':'fixture-1','ElectronAsarIntegrity':{'Resources/app.asar':{'algorithm':'SHA256','hash':sha(header)}}}
    (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run(['xattr','-w','org.orxooo.claudefont.fixture','retain-me',str(app)],check=True)
    original=snapshot(app); nested=sha(dylib.read_bytes()); original_archive=archive.read_bytes()
    config=work/'config.json'; config.write_text(json.dumps({'font':'Songti SC'}))
    env=dict(os.environ,CLAUDEFONT_CONFIG=str(config),CLAUDEFONT_DATA_DIR=str(work/'state'))
    def run(command,*args,code=0,extra=None):
        result=subprocess.run([str(BINARY),command,'--app',str(app),*args],env=dict(env,**(extra or {})),text=True,capture_output=True)
        if result.returncode!=code:
            selected=str(app)
            for i,value in enumerate(args[:-1]):
                if value=='--app': selected=args[i+1]
            data=Path(dict(env,**(extra or {}))['CLAUDEFONT_DATA_DIR'])
            smoke=data/'targets'/sha(str(Path(selected).absolute()).encode())[:20]/'smoke.log'
            diagnostic=smoke.read_text(errors='replace')[-1000:] if smoke.exists() else '(no selected-target smoke log)'
            raise AssertionError(f'{command}: exit {result.returncode}, expected {code}\n{result.stdout}\n{result.stderr}\nFixture smoke: {diagnostic}')
        return result
    def status():return json.loads(run('status','--json').stdout)
    initial=status()
    if initial['state']!='clean' or not initial['canApply']: print('Initial status:',json.dumps(initial),flush=True)
    check('valid signed fixture and directory link accepted',initial['state']=='clean' and initial['canApply'])
    check('CLI version identity',subprocess.check_output([str(BINARY),'--version'],text=True).strip()=='claudefont 1.0.0')
    run('doctor','--json');check('access probe leaves original bundle intact',snapshot(app)==original)
    run('install','-y');state=status();raw,patched=unpack(archive)
    check('renderer appended beyond source-map comment',patched['.vite/build/mainView.js'].startswith(files['.vite/build/mainView.js']+b'\n'))
    check('main and other payloads untouched',all(patched[k]==v for k,v in files.items() if k!='.vite/build/mainView.js'))
    check('integrity metadata updated',plistlib.loads((app/'Contents/Info.plist').read_bytes())['ElectronAsarIntegrity']['Resources/app.asar']['hash']==sha(raw))
    check('nested signing bytes retained',sha(dylib.read_bytes())==nested)
    check('post-pack signed external resource stays byte-identical',external.read_bytes()==external_signed)
    check('applied status agrees with configuration',state['state']=='applied' and state['settingsMatch'])
    run('install','-y');check('reapply contains one injection',unpack(archive)[1]['.vite/build/mainView.js'].count(b'/* claudefont-renderer-1 */')==1)
    run('uninstall','-y');check('full byte/mode restoration',snapshot(app)==original and archive.read_bytes()==original_archive)
    check('unrelated extended attribute preserved',subprocess.check_output(['xattr','-p','org.orxooo.claudefont.fixture',str(app)],text=True).strip()=='retain-me')
    run('install','-y',code=1,extra={'CLAUDEFONT_FIXTURE_FAIL_PATCH':'1'})
    check('startup failure restores entire target',snapshot(app)==original and status()['state']=='clean')
    config.write_text(json.dumps({'font':'Songti SC','code_font_terminal':'Menlo','code_scale_terminal':125}))
    run('install','-y');terminal=unpack(archive)[1]['.vite/renderer/main_window/terminal.js'].decode()
    node=work/'terminal.js';node.write_text(terminal+'\nconsole.log(JSON.stringify(globalThis.terminalOptions));')
    options=json.loads(subprocess.check_output(['node',str(node)],text=True))
    check('terminal uses measured constructor options',options['fontFamily']=='Menlo' and options['fontSize']==20 and options['cursorBlink'])
    check('terminal overrides recorded',status()['compatibility']['installedRegions']['terminal'])
    run('uninstall','-y')
    config.write_text(json.dumps({'font':'Songti SC'}))
    run('install','-y')
    corrupted=bytearray(archive.read_bytes());corrupted[-1]^=1;archive.write_bytes(corrupted)
    check('damaged applied ASAR is reported unsupported',status()['state']=='unsupported')
    run('uninstall','-y');check('damaged applied resources restore from pristine backup',snapshot(app)==original)
    run('backups','--purge','-y');check('corrupt-current snapshots can be purged after restoration',not list((work/'state').rglob('manifest.json')))
    run('install','-y');(app/'Contents/MacOS/Fixture').unlink()
    run('uninstall','-y');check('missing current runtime restores full original bundle',snapshot(app)==original)
    # Kill this fixture operation during the isolated startup window, then recover.
    process=subprocess.Popen([str(BINARY),'install','--app',str(app),'-y'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    import time
    deadline=time.monotonic()+30
    while time.monotonic()<deadline and not list((work/'state').rglob('journal.json')) and process.poll() is None: time.sleep(.01)
    journals=list((work/'state').rglob('journal.json'))
    if not journals: raise AssertionError('fixture operation did not reach transaction journal')
    process.kill();process.communicate()
    # The smoke child is our fixture binary; allow its finite lifetime to finish before recovery.
    for _ in range(2200):
        result=subprocess.run(['/bin/ps','-axo','comm='],text=True,capture_output=True)
        if str(app)+'/Contents/' not in result.stdout: break
        time.sleep(.01)
    run('uninstall','-y');check('interrupted transaction restores exact original',snapshot(app)==original)
    def signed_archive(contents, extras=None):
        archive.write_bytes(pack(contents,extras)); raw,_=unpack(archive)
        info['ElectronAsarIntegrity']['Resources/app.asar']['hash']=sha(raw)
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stderr=subprocess.DEVNULL)
    variants=[
        ('dot prefix','./.vite/build/mainView.js',{}),
        ('parent normalization','.vite/build/../build/mainView.js',{}),
        ('extensionless entry','.vite/build/mainView',{}),
        ('file link','entry',{'entry':{'link':'.vite/build/mainView.js'}}),
        ('directory link','build/mainView.js',{'build':{'link':'.vite/build'}}),
        ('directory entry','.vite/build',{}),
    ]
    for name,main,extras in variants:
        content=dict(files);content['package.json']=json.dumps({'main':main}).encode()
        if name=='directory entry': content['.vite/build/package.json']=b'{"main":"mainView.js"}'
        signed_archive(content,extras);before=snapshot(app)
        run('install','-y',code=1)
        check('main protection: '+name,not status()['canApply'] and snapshot(app)==before)
    content=dict(files);content['package.json']=b'{"main":"./.vite/renderer/main_window/terminal"}'
    signed_archive(content);before=snapshot(app)
    config.write_text(json.dumps({'font':'Songti SC','code_font_terminal':'Menlo'}))
    run('install','-y',code=1)
    check('terminal adapter excludes resolved main entry',not status()['canApply'] and snapshot(app)==before)
    archive.write_bytes(original_archive)
    # Restore the whole fixture: top-level signing also binds metadata to executable bytes.
    original_backup=next(p for p in (work/'state').rglob('manifest.json') if json.loads(p.read_text())['pristine'])
    shutil.copytree(original_backup.parent/'Application.app',app,dirs_exist_ok=True,symlinks=True)
    external.unlink();external.symlink_to(dylib)
    run('install','-y',code=1);check('unpacked symlink still refuses modification',external.is_symlink() and sha(dylib.read_bytes())==nested)
    external.unlink();external.write_bytes(external_signed);external.chmod(0o755)
    config.write_text(json.dumps({'font':'bad";body{color:red}'}))
    run('install','-y',code=1);check('invalid settings refuse before mutation',snapshot(app)==original)
    config.write_text(json.dumps({'font':'Songti SC'}))
    held=resources/'original.asar';archive.rename(held);archive.symlink_to(held)
    run('install','-y',code=1);check('archive symlink refuses without following it',held.read_bytes()==original_archive)
    archive.unlink();held.rename(archive)
    corrupted=bytearray(original_archive);corrupted[-1]^=1;archive.write_bytes(corrupted)
    run('install','-y',code=1);check('payload integrity corruption refuses mutation',archive.read_bytes()==corrupted)
    archive.write_bytes(original_archive)
    foreign=pack(dict(files,**{'.vite/build/mainView.js':files['.vite/build/mainView.js']+b'\n;/* external-font-v9 */',
                              '.vite/renderer/main_window/index.html':b'<html>Previous reading style</html>'}),
                 {'alias':{'link':'.vite/renderer'},'native.node':external_record})
    archive.write_bytes(foreign);raw,_=unpack(archive);info['ElectronAsarIntegrity']['Resources/app.asar']['hash']=sha(raw)
    (resources/'app.asar.bak').write_bytes(original_archive)
    (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info));subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stderr=subprocess.DEVNULL)
    foreign_snapshot=snapshot(app);run('install','-y',code=1);check('foreign patch does not stack',snapshot(app)==foreign_snapshot)
    check('foreign state clearly unsupported',status()['state']=='unsupported')
    # Explicit previous-install migration uses only independent, signed fixtures.
    # Keep this transaction target independent from earlier repeated installs,
    # damage recovery and app replacement tests at the original fixture path.
    migrated_app=work/'MigrationFixture.app';shutil.copytree(app,migrated_app,symlinks=True)
    app=migrated_app;resources=app/'Contents/Resources';archive=resources/'app.asar'
    pristine=work/'Pristine.app'
    shutil.copytree(original_backup.parent/'Application.app',pristine,symlinks=True)
    previous=work/'Previous.app';shutil.copytree(app,previous,symlinks=True)
    previous_bytes=archive.read_bytes()
    old_folder=work/'previous-settings';old_folder.mkdir()
    old_config=old_folder/'config.json';old_themes=old_folder/'themes.json'
    old_config.write_text(json.dumps({'font':'PingFang SC','font_scale':110,'bg_color':'#F0EEE6',
        'dark_theme':'warm','font_face':'private-face','app_path':'/private/unused','runtime_flag':True}))
    old_themes.write_text(json.dumps([{'name':'My reading','schemaVersion':1,
        'settings':{'font':'PingFang SC','font_scale':'110','dark_theme':'warm'}}]))
    old_config_bytes=old_config.read_bytes();old_theme_bytes=old_themes.read_bytes()
    imported_themes=config.parent/'themes.json';imported_themes.write_text('[]')
    previous_config=config.read_bytes();previous_themes=imported_themes.read_bytes()
    migration_args=['--backup',str(pristine),'--settings',str(old_config),'--themes',str(old_themes),'-y']
    def reject_migration(name,*args):
        before=snapshot(app);cfg=config.read_bytes();themes=imported_themes.read_bytes()
        manifests=sorted(str(p) for p in (work/'state').rglob('manifest.json'))
        run('migrate',*args,code=1)
        check('migration refuses '+name+' before modification',snapshot(app)==before and config.read_bytes()==cfg
              and imported_themes.read_bytes()==themes and manifests==sorted(str(p) for p in (work/'state').rglob('manifest.json')))
    old_config.write_text(json.dumps({'font':{'invalid':'value'}}))
    reject_migration('invalid configuration',*migration_args)
    old_config.write_bytes(old_config_bytes)
    old_themes.write_text(json.dumps([{'name':'Bad','schemaVersion':8,'settings':{'font':'PingFang SC'}}]))
    reject_migration('invalid themes',*migration_args)
    old_themes.write_bytes(old_theme_bytes)
    link=work/'Linked.app';link.symlink_to(pristine)
    reject_migration('symlink backup','--backup',str(link),'--settings',str(old_config),'-y')
    linked_settings=old_folder/'linked.json';linked_settings.symlink_to(old_config)
    reject_migration('symlink settings','--backup',str(pristine),'--settings',str(linked_settings),'-y')
    bad=work/'Wrong.app'
    def backup_variant(label, transform):
        if bad.exists(): shutil.rmtree(bad)
        shutil.copytree(pristine,bad,symlinks=True)
        transform(bad)
        subprocess.run(['codesign','--force','--sign','-',str(bad)],check=True,stderr=subprocess.DEVNULL)
        reject_migration(label,'--backup',str(bad),'--settings',str(old_config),'-y')
    def edit_info(bundle,key,value):
        dest=bundle/'Contents/Info.plist';obj=plistlib.loads(dest.read_bytes());obj[key]=value;dest.write_bytes(plistlib.dumps(obj))
    backup_variant('mismatched version',lambda b:edit_info(b,'CFBundleShortVersionString','fixture-2'))
    backup_variant('mismatched identity',lambda b:edit_info(b,'CFBundleIdentifier','invalid.application'))
    def edit_archive(bundle,key,value):
        dest=bundle/'Contents/Resources/app.asar';dest.write_bytes(pack(dict(files,**{key:value}),{'alias':{'link':'.vite/renderer'},'native.node':external_record}))
        raw,_=unpack(dest);meta=bundle/'Contents/Info.plist';obj=plistlib.loads(meta.read_bytes())
        obj['ElectronAsarIntegrity']['Resources/app.asar']['hash']=sha(raw);meta.write_bytes(plistlib.dumps(obj))
    backup_variant('main tamper',lambda b:edit_archive(b,'main.js',b'// tampered main'))
    backup_variant('nonrenderer tamper',lambda b:edit_archive(b,'plain.txt',b'changed'))
    backup_variant('nonpristine backup',lambda b:edit_archive(b,'.vite/build/mainView.js',files['.vite/build/mainView.js']+b'\n;/* external-font-v9 */'))
    def change_runtime(bundle):
        runtime=bundle/'Contents/MacOS/Fixture'
        subprocess.run(['xcrun','clang',str(lib),'-dynamiclib','-o',str(runtime)],check=True)
        subprocess.run(['codesign','--force','--sign','-',str(runtime)],check=True,stderr=subprocess.DEVNULL)
    backup_variant('runtime mismatch',change_runtime)
    mismatch_source=work/'different-library.c';mismatch_source.write_text('int fixture(void){return 87;}')
    def change_nested_library(bundle):
        library=bundle/'Contents/Frameworks/Fixture.dylib'
        subprocess.run(['xcrun','clang','-dynamiclib',str(mismatch_source),'-o',str(library)],check=True)
        subprocess.run(['codesign','--force','--sign','-',str(library)],check=True,stderr=subprocess.DEVNULL)
    backup_variant('valid signed nested library mismatch',change_nested_library)
    check('mismatched nested library fixture signature is valid',subprocess.run(['codesign','--verify','--deep','--strict',str(bad)],capture_output=True).returncode==0)
    backup_variant('extra nonarchive resource',lambda b:(b/'Contents/Resources/extra.txt').write_text('Unrelated resource'))
    backup_variant('unrelated application metadata',lambda b:edit_info(b,'NSHighResolutionCapable',True))
    artifact=resources/'app.asar.bak'
    artifact.write_bytes(b'Incorrect archive backup')
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stderr=subprocess.DEVNULL)
    reject_migration('mismatched archive backup artifact',*migration_args)
    artifact.write_bytes(original_archive)
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stderr=subprocess.DEVNULL)
    check('legitimate archive backup artifact matches pristine bytes',artifact.read_bytes()==(pristine/'Contents/Resources/app.asar').read_bytes())
    # Immutable fixture output makes the second atomic write fail after config
    # succeeded. Clear the fixture flag afterward; no system permissions change.
    subprocess.run(['chflags','uchg',str(imported_themes)],check=True)
    reject_before=snapshot(app);cfg_before=config.read_bytes()
    try:
        run('migrate',*migration_args,code=1)
        check('migration output failure rolls settings back',snapshot(app)==reject_before and config.read_bytes()==cfg_before
              and imported_themes.read_bytes()==previous_themes)
    finally: subprocess.run(['chflags','nouchg',str(imported_themes)],check=True)
    run('migrate',*migration_args)
    check('migration leaves previous app and source files intact',snapshot(app)==foreign_snapshot and archive.read_bytes()==previous_bytes
          and old_config.read_bytes()==old_config_bytes and old_themes.read_bytes()==old_theme_bytes and snapshot(pristine)==original)
    imported=json.loads(config.read_text());themes=json.loads(imported_themes.read_text())
    check('portable font palette and themes imported',imported['font']=='PingFang SC' and imported['font_scale']=='110'
          and imported['dark_theme']=='warm' and imported['bg_color']=='#F0EEE6' and 'font_face' not in imported
          and 'app_path' not in imported and len(themes)==1 and themes[0]['name']=='My reading')
    state=status()
    check('verified previous state can continue',state['state']=='previous' and state['canApply'] and not state['settingsMatch']
          and state['previousReady'] and state['font']=='PingFang SC')
    receipt=next((work/'state').rglob('previous.json'));registered=json.loads(receipt.read_text())
    managed=next(p for p in (work/'state').rglob('manifest.json') if json.loads(p.read_text())['id']==registered['backupID'])
    check('complete pristine copy imported and signature valid',snapshot(managed.parent/'Application.app')==original
          and subprocess.run(['codesign','--verify','--deep','--strict',str(managed.parent/'Application.app')],capture_output=True).returncode==0)
    # Update invalidation has separate targets. Rebuilding a signed executable
    # at the transaction fixture's existing path can leave macOS launch state
    # pending; these checks only need the mutated target's status.
    def receipt_target(name):
        chosen=work/(name+'.app');shutil.copytree(previous,chosen,symlinks=True)
        chosen_env={'CLAUDEFONT_CONFIG':str(work/(name+'-config.json')),'CLAUDEFONT_DATA_DIR':str(work/(name+'-state'))}
        run('migrate','--app',str(chosen),'--backup',str(pristine),'--settings',str(old_config),'-y',extra=chosen_env)
        return chosen,chosen_env
    changed_target,changed_env=receipt_target('ArchiveChanged')
    changed=dict(files,**{'.vite/build/mainView.js':files['.vite/build/mainView.js']+b'\n;/* external-font-v9 */',
                         '.vite/renderer/main_window/index.html':b'<html>changed again</html>'})
    changed_archive=changed_target/'Contents/Resources/app.asar'
    changed_archive.write_bytes(pack(changed,{'alias':{'link':'.vite/renderer'},'native.node':external_record}))
    changed_header,_=unpack(changed_archive);changed_plist=changed_target/'Contents/Info.plist'
    changed_info=plistlib.loads(changed_plist.read_bytes());changed_info['ElectronAsarIntegrity']['Resources/app.asar']['hash']=sha(changed_header)
    changed_plist.write_bytes(plistlib.dumps(changed_info))
    subprocess.run(['codesign','--force','--sign','-',str(changed_target)],check=True,stderr=subprocess.DEVNULL)
    changed_status=json.loads(run('status','--app',str(changed_target),'--json',extra=changed_env).stdout)
    check('previous receipt invalidates on archive change',changed_status['state']=='unsupported' and not changed_status['canApply'])
    updated_target,updated_env=receipt_target('VersionChanged')
    edit_info(updated_target,'CFBundleShortVersionString','fixture-2')
    subprocess.run(['codesign','--force','--sign','-',str(updated_target)],check=True,stderr=subprocess.DEVNULL)
    updated_status=json.loads(run('status','--app',str(updated_target),'--json',extra=updated_env).stdout)
    check('previous receipt invalidates on application update',updated_status['state']=='unsupported' and not updated_status['canApply'])
    run('install','-y',code=1,extra={'CLAUDEFONT_FIXTURE_FAIL_PATCH':'1'})
    check('transition startup failure restores exact previous app',snapshot(app)==foreign_snapshot and status()['state']=='previous')
    run('install','-y');transition=unpack(archive)[1]
    check('transition replaces rather than stacks previous patch',transition['.vite/build/mainView.js'].startswith(files['.vite/build/mainView.js'])
          and transition['.vite/build/mainView.js'].count(b'/* claudefont-renderer-1 */')==1
          and b'external-font-v9' not in transition['.vite/build/mainView.js'])
    check('transition drops the previous archive backup artifact',not (resources/'app.asar.bak').exists())
    check('transition uses pristine renderer payload',transition['.vite/renderer/main_window/index.html']==files['.vite/renderer/main_window/index.html']
          and transition['main.js']==files['main.js'] and status()['state']=='applied')
    run('uninstall','-y')
    check('transition restores exact pristine vendor bundle',snapshot(app)==original and archive.read_bytes()==original_archive)
    check('restoration preserves original imported source files',old_config.read_bytes()==old_config_bytes and old_themes.read_bytes()==old_theme_bytes)
    # Equivalent runtime code with a large harmless entitlement allocates a
    # different signature / __LINKEDIT region. Import must normalize copies only.
    expanded=work/'Expanded.app';shutil.copytree(previous,expanded,symlinks=True)
    entitlements=work/'padding.plist'
    entitlements.write_bytes(plistlib.dumps({'io.github.orxooo.claudefont.fixture-padding':'x'*80_000}))
    subprocess.run(['codesign','--force','--sign','-','--entitlements',str(entitlements),str(expanded)],check=True,stderr=subprocess.DEVNULL)
    expanded_runtime=expanded/'Contents/MacOS/Fixture'
    check('signature-allocation fixture differs and verifies',expanded_runtime.stat().st_size!=(app/'Contents/MacOS/Fixture').stat().st_size
          and subprocess.run(['codesign','--verify','--deep','--strict',str(expanded)],capture_output=True).returncode==0)
    expanded_before=snapshot(expanded)
    expanded_env={'CLAUDEFONT_CONFIG':str(work/'expanded-config.json'),'CLAUDEFONT_DATA_DIR':str(work/'expanded-state')}
    run('migrate','--app',str(expanded),'--backup',str(pristine),'--settings',str(old_config),'-y',extra=expanded_env)
    expanded_status=json.loads(run('status','--app',str(expanded),'--json',extra=expanded_env).stdout)
    check('equivalent runtime with different signature allocation migrates unchanged',snapshot(expanded)==expanded_before
          and expanded_status['state']=='previous' and expanded_status['canApply'])
print(f'All {count} independent engine checks passed')
