#!/usr/bin/env python3
"""Runs cases.json against one model on the phone; prints per-case results and a score."""
import json, subprocess, sys, time, re, shlex
name, model, mmproj, tmpl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
cases = json.load(open('cases.json'))
only = sys.argv[5].split(',') if len(sys.argv) > 5 else None
res = []
for c in cases:
    if only and c['cat'] not in only: continue
    if c['image']:
        if mmproj == '-': continue
        args = ['./llama-mtmd-cli', '-m', model, '--mmproj', mmproj, '--image', c['image'], '--jinja']
    elif tmpl == 'raw':
        sysblock = f"<|im_start|>system\n{c['sys']}<|im_end|>\n" if c['sys'] else ''
        raw = sysblock + f"<|im_start|>user\n{c['prompt']}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
        args = ['./llama-completion', '-m', model, '-no-cnv', '--no-display-prompt', '-p', raw]
    else:
        args = ['./llama-completion', '-m', model, '--jinja', '-rea', 'off', '-cnv', '-st', '--no-display-prompt']
    if tmpl != 'raw' or c['image']:
        args += ['-p', c['prompt']]
        if c['sys']: args += ['-sys', c['sys']]
    args += ['-t', '4', '-c', '4096', '-n', '400', '--temp', '0', '-r', '<|im_end|>']
    cmd = 'cd /data/local/tmp/ev && timeout 240 ' + ' '.join(shlex.quote(a) for a in args) + ' </dev/null 2>err.txt; grep -E "eval time|prompt eval|load time" err.txt | tail -3 1>&2'
    t = time.time()
    p = subprocess.run(['adb', 'shell', cmd], capture_output=True, text=True)
    dt = time.time() - t
    out = re.sub(r'<think>[\s\S]*?</think>', '', p.stdout).replace('[end of text]', '').replace('<|im_end|>','').strip()
    low = out.lower()
    ok = True
    if c['any']: ok &= any(a.lower() in low for a in c['any'])
    if c['all']: ok &= all(a.lower() in low for a in c['all'])
    if c['none']: ok &= not any(a.lower() in low for a in c['none'])
    if c['lines']: ok &= len([l for l in out.split('\n') if l.strip()]) == c['lines']
    tps = re.findall(r'eval time =.*?([\d.]+) tokens per second', p.stderr)
    res.append(dict(id=c['id'], cat=c['cat'], ok=bool(ok), secs=round(dt, 1), tps=tps[-1] if tps else '', out=out[:300]))
    print(f"{c['id']:4} {'PASS' if ok else 'fail'} {dt:5.1f}s tps={tps[-1] if tps else '?'} | {out[:110]!r}", flush=True)
json.dump(res, open(f'res_{name}.json', 'w'), indent=1)
by = {}
for r in res: by.setdefault(r['cat'], []).append(r['ok'])
print(name, 'TOTAL', sum(r['ok'] for r in res), '/', len(res), ' ', ' '.join(f"{k}:{sum(v)}/{len(v)}" for k, v in by.items()), ' mean s/case', round(sum(r['secs'] for r in res)/len(res), 1))
