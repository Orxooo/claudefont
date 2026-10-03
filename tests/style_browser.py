#!/usr/bin/env python3
# Copyright (C) 2026 Orxooo
# SPDX-License-Identifier: GPL-3.0-only
"""Compile independent style checks and run a synthetic DOM browser regression."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='claudefont-style-') as directory:
    target = Path(directory)
    binary = target / 'style-checks'
    subprocess.run(['swiftc', '-swift-version', '5', str(ROOT/'shared/Appearance.swift'),
                    str(ROOT/'shared/StyleCSS.swift'), str(ROOT/'tests/style_checks.swift'), '-o', str(binary)], check=True)
    subprocess.run([str(binary), str(target)], check=True)
    (target/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>claudefont independent renderer checks</title>
<style>body{font-size:16px;color:#252B32}.font-claude-response{font-size:18px}pre{font-size:14px}code{font-size:inherit}</style>
<main><div class="font-claude-response" id="reply">Reading sample 中文<p>Paragraph</p></div>
<pre id="block"><code>const answer = 42;</code></pre><div class="font-claude-response" id="inherited" style="font-size:18px"><pre style="font-size:inherit" id="initial-inherited">initial</pre></div><div id="late-shadow"></div><div id="shadow"></div><output id="result">running</output></main>
<script>const shadow=document.querySelector('#shadow').attachShadow({mode:'open'});shadow.innerHTML='<pre id="inside" style="font-size:14px"><code>shadow example</code></pre>';</script>
<script src="renderer.js"></script>
<script>
window.results=[];
const check=(name,ok)=>results.push({name,ok:Boolean(ok)});
const frame=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
window.done=(async()=>{
 await frame();
 for(const [name,text] of [['CFHanBody','汉'],['CFHanUI','汉'],['CFLatinBody','Aa'],['CFLatinUI','Aa']]){
  try {const faces=await document.fonts.load('16px "'+name+'"',text);check(name+' actually loads',faces.length>0&&faces.every(f=>f.status==='loaded'));}
  catch {check(name+' actually loads',false);}
 }
 check('reply scaling',Math.abs(parseFloat(getComputedStyle(document.querySelector('#reply')).fontSize)-19.8)<0.1);
 check('block scaling once',Math.abs(parseFloat(getComputedStyle(document.querySelector('#block')).fontSize)-17.5)<0.1);
 check('nested code inherits block scale',Math.abs(parseFloat(getComputedStyle(document.querySelector('#block code')).fontSize)-17.5)<0.1);
 check('region font',getComputedStyle(document.querySelector('#block')).fontFamily.includes('Courier New'));
 check('reading width',Math.abs(document.querySelector('#reply').getBoundingClientRect().width-680)<1);
 check('reading line height',Math.abs(parseFloat(getComputedStyle(document.querySelector('#reply')).lineHeight)-35.64)<0.2);
 check('light background',getComputedStyle(document.body).backgroundColor==='rgb(240, 238, 230)');
 check('shadow stylesheet',Boolean(shadow.querySelector('style[data-claudefont-sheet]')));
 check('shadow region size',Math.abs(parseFloat(getComputedStyle(shadow.querySelector('#inside')).fontSize)-17.5)<0.1);
 document.documentElement.classList.add('dark');await frame();
 check('dark palette',getComputedStyle(document.body).backgroundColor==='rgb(37, 33, 31)');
 const added=document.createElement('pre');added.textContent='dynamic code';added.style.fontSize='14px';document.querySelector('main').append(added);await frame();
 const inherited=document.createElement('pre');inherited.style.fontSize='inherit';inherited.textContent='later inherited';document.querySelector('#inherited').append(inherited);await frame();
 check('dynamic inherited scale matches initial',Math.abs(parseFloat(getComputedStyle(inherited).fontSize)-parseFloat(getComputedStyle(document.querySelector('#initial-inherited')).fontSize))<0.1);
 const late=document.querySelector('#late-shadow').attachShadow({mode:'open'});late.innerHTML='<pre style="font-size:14px">late shadow</pre>';
 await new Promise(resolve=>setTimeout(resolve,1150));await frame();
 check('late shadow discovered',Boolean(late.querySelector('style[data-claudefont-sheet]'))&&late.querySelector('pre').getAttribute('data-claudefont-zone')==='block');
 check('dynamic content',added.getAttribute('data-claudefont-zone')==='block'&&Math.abs(parseFloat(getComputedStyle(added).fontSize)-17.5)<0.1);
 document.querySelectorAll('style[data-claudefont-sheet]').forEach(el=>el.remove());await frame();
 check('removed sheet restored',Boolean(document.head.querySelector('style[data-claudefont-sheet]')));
 document.querySelector('#result').textContent=JSON.stringify(results);
 return results;
})();
</script>''')
    env = dict(os.environ, AGENT_BROWSER_SESSION='claudefont-independent-style')
    cli = ['npx', '--yes', 'agent-browser']
    try:
        subprocess.run(cli+['open', (target/'index.html').as_uri()], env=env, check=True, stdout=subprocess.DEVNULL)
        reply = subprocess.check_output(cli+['eval', '--stdin'],input='(async () => JSON.stringify(await window.done))()',text=True,env=env)
        parsed = json.loads(reply)
        if isinstance(parsed,str): parsed=json.loads(parsed)
        # Some CLI versions envelope evaluated output; handle their explicit data field.
        if isinstance(parsed,dict) and 'data' in parsed: parsed=parsed['data'].get('result',parsed['data'])
        if isinstance(parsed,str): parsed=json.loads(parsed)
        for item in parsed: print(('PASS' if item['ok'] else 'FAIL')+': '+item['name'])
        if not all(item['ok'] for item in parsed): raise SystemExit(1)
        print(f"All {len(parsed)} browser style checks passed")
    finally:
        subprocess.run(cli+['close'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
