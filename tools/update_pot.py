#!/usr/bin/env python3
"""Regenerate cwngsync.koplugin/l10n/templates/cwngsync.pot from the _() and
N_() calls in the plugin's Lua files.

Update a translation afterwards with:
    msgmerge -U cwngsync.koplugin/l10n/<lang>/cwngsync.po cwngsync.koplugin/l10n/templates/cwngsync.pot
"""
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cwngsync.koplugin")
STR = r'(?:"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'|\[\[(.*?)\]\])'
SINGULAR = re.compile(r'(?<![\w.])_\(\s*' + STR + r'\s*\)', re.S)
PLURAL = re.compile(r'(?<![\w.])N_\(\s*' + STR + r'\s*,\s*' + STR + r'\s*,', re.S)


def lua_string(groups):
    dq, sq, long = groups
    if long is not None:
        return long
    s = dq if dq is not None else sq
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def po_string(s):
    if "\n" not in s[:-1]:
        return '"%s"' % po_escape(s)
    parts = s.split("\n")
    lines = [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
    return '""\n' + "\n".join('"%s"' % po_escape(line) for line in lines)


def main():
    entries, order = {}, []
    for name in sorted(os.listdir(ROOT)):
        if not name.endswith(".lua"):
            continue
        src = open(os.path.join(ROOT, name), encoding="utf-8").read()
        for pattern, plural in ((SINGULAR, False), (PLURAL, True)):
            for m in pattern.finditer(src):
                g = m.groups()
                msgid = lua_string(g[0:3])
                ref = "%s:%d" % (name, src.count("\n", 0, m.start()) + 1)
                if msgid not in entries:
                    entries[msgid] = {"refs": [], "plural": lua_string(g[3:6]) if plural else None}
                    order.append(msgid)
                entries[msgid]["refs"].append(ref)

    out = [
        "# Translation template for the cwngsync.koplugin KOReader plugin.",
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: cwngsync.koplugin\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"',
        "",
    ]
    for msgid in order:
        e = entries[msgid]
        out.append("#: " + " ".join(e["refs"]))
        out.append("msgid " + po_string(msgid))
        if e["plural"]:
            out.append("msgid_plural " + po_string(e["plural"]))
            out += ['msgstr[0] ""', 'msgstr[1] ""']
        else:
            out.append('msgstr ""')
        out.append("")

    path = os.path.join(ROOT, "l10n", "templates", "cwngsync.pot")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("%d strings -> %s" % (len(order), os.path.relpath(path)))


if __name__ == "__main__":
    main()
