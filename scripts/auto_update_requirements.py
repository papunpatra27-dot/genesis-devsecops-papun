#!/usr/bin/env python3
"""
Script: auto_update_requirements.py
Usage: python scripts/auto_update_requirements.py <pip-audit-json> <requirements-file>

Reads pip-audit JSON and updates the pinned versions in requirements.txt for
packages that have an available fixed version. Prints 'true' to stdout if it
made changes, otherwise 'false'. Always exits 0.

This script is conservative: it only updates lines that contain an exact
package name match (case-insensitive) and replaces the version pin with
==<fixed_version>.
"""
import json
import sys
from packaging.version import parse as parse_version
from pathlib import Path


def load_json(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return None


def gather_fixes(data):
    fixes = {}
    if data is None:
        return fixes
    # handle different possible schema shapes
    # 1) top-level dict with 'vulnerabilities' or 'vulns'
    if isinstance(data, dict):
        candidates = []
        if 'vulnerabilities' in data:
            candidates = data['vulnerabilities']
        elif 'vulns' in data:
            candidates = data['vulns']
        else:
            # maybe a dict with package names as keys
            for k, v in data.items():
                if isinstance(v, dict) and ('fix_versions' in v or 'vulns' in v):
                    candidates.append({'name': k, **v})
    elif isinstance(data, list):
        candidates = data
    else:
        candidates = []

    for item in candidates:
        name = None
        fixes_list = []
        # item may be a dict with keys like 'name','package','vulns'
        if isinstance(item, dict):
            name = item.get('name') or item.get('package') or item.get('package_name')
            # direct fix_versions
            fv = item.get('fix_versions') or item.get('fixed_versions') or item.get('fix_version')
            if fv:
                if isinstance(fv, list):
                    fixes_list.extend(fv)
                else:
                    fixes_list.append(fv)
            # nested vulns
            nested = None
            if 'vulns' in item and isinstance(item['vulns'], list):
                nested = item['vulns']
            elif 'vulnerabilities' in item and isinstance(item['vulnerabilities'], list):
                nested = item['vulnerabilities']
            if nested:
                for n in nested:
                    nv = n.get('fix_versions') or n.get('fixed_versions') or n.get('fix_version')
                    if nv:
                        if isinstance(nv, list):
                            fixes_list.extend(nv)
                        else:
                            fixes_list.append(nv)
        # fallback: if item contains 'id' and 'package' fields
        if not name and isinstance(item, dict) and 'package' in item and isinstance(item['package'], dict):
            name = item['package'].get('name')
            fv = item.get('fix_versions') or item.get('fixed_versions')
            if fv:
                if isinstance(fv, list):
                    fixes_list.extend(fv)
                else:
                    fixes_list.append(fv)

        if name and fixes_list:
            # pick the highest version
            try:
                chosen = sorted(fixes_list, key=lambda v: parse_version(str(v)))[-1]
                fixes[name.lower()] = str(chosen)
            except Exception:
                fixes[name.lower()] = str(fixes_list[0])
    return fixes


def parse_requirement_line(line):
    # very small parser: parse "name==x", "name>=x", "name" etc.
    s = line.strip()
    if not s or s.startswith('#'):
        return None, None, line
    # split on ; (env markers)
    parts = s.split(';', 1)
    req = parts[0].strip()
    marker = ';' + parts[1] if len(parts) > 1 else ''
    for op in ['==', '>=', '<=', '~=', '!=', '>', '<']:
        if op in req:
            name, ver = req.split(op, 1)
            return name.strip(), op + ver.strip(), marker
    # bare name or vcs link
    if 'git+' in req or '://' in req:
        return None, None, line
    name = req
    return name.strip(), None, marker


def main():
    if len(sys.argv) != 3:
        print('false')
        return
    pip_audit_json = Path(sys.argv[1])
    req_file = Path(sys.argv[2])
    data = load_json(pip_audit_json)
    fixes = gather_fixes(data)
    if not fixes:
        print('false')
        return
    changed = False
    if not req_file.exists():
        print('false')
        return
    lines = req_file.read_text(encoding='utf-8').splitlines()
    out_lines = []
    for ln in lines:
        name, ver, marker = parse_requirement_line(ln)
        if name and name.lower() in fixes:
            newver = '==' + fixes[name.lower()]
            out_lines.append(f"{name}{newver}{marker}")
            if ver != newver:
                changed = True
        else:
            out_lines.append(ln)
    if changed:
        req_file.write_text('\n'.join(out_lines) + '\n', encoding='utf-8')
        print('true')
    else:
        print('false')

if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('false')
        sys.exit(0)
