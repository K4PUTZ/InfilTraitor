#!/usr/bin/env python3
##
## worker_typing_check.py — no operator on an UNTYPED value in GDScript that runs on a worker thread (2026-10-19)
##
## WHY. Godot 4.6.1 and 4.7.2 (upstream `master` too, checked 2026-10-19: the opcode code is identical) compile an operator whose operand the compiler cannot type to `OPCODE_OPERATOR`, which on its FIRST run
## patches its own bytecode (signature, then return type, then the evaluator pointer) under a mutex its fast path does not take. A
## second thread running the same instruction at that moment reads the new signature and calls the pointer before it is written:
## a NULL call, a crash on the worker, and the decoy line `ERROR: /root: ... propagate_notification()` (the crash handler notifying
## /root from that thread). It hit the parallel light apply at map load (`VoxelLightField._anchor_level()`, fixed in f3d8a74c).
## Record and measurements: `PROMPTS/PLANNING/PERFORMANCE_BUDGET_MASTER_PLAN.md`, top block of 2026-10-19.
##
## WHAT IS FLAGGED (the classes measured to crash, one fresh-compile probe each, 400 compiles x 64 tasks): an operator (arithmetic,
## comparison, `and` / `or` / `not`, bitwise, compound assignment) with an operand that is
##   - an untyped parameter, an untyped `var x = ...`, an untyped loop variable over anything but `range()` / a packed array / a typed array;
##   - a raw element of an untyped `Array` or of a `Dictionary` (`a[i]`, `d[k]`), or a `Dictionary.get()` result, not converted;
##   - a property of an untyped value;
## and any `match` (a `match` on another class's constants tests untyped temporaries even when the subject is typed; an `if` chain
## is always safe). NOT flagged: a value converted (`int(x)`, `float(x)`, `bool(x)`, `x as T`), a literal, a typed name.
##
## WHERE. Every function reachable from a `WorkerThreadPool.add_task` / `add_group_task` callable (an inline lambda, a lambda held
## in a variable, a method, a `.bind()`ed method), following calls by name, `ClassName.func`, preload aliases, typed receivers and,
## for an untyped receiver, a method name defined only once in the project. Heuristic, not the compiler: a reviewed false positive
## goes in `worker_typing_exceptions.txt` (`path | function | code`, the code exactly as written, and a reason).
##
## Usage:  python3 tools/persistent/worker_typing_check.py [--list-roots] [--list-reach]
## Exit 0 = clean, 1 = a hazard (each printed as path:line function | why | code).

import argparse
import glob
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = "godot/scripts"
EXCEPTIONS = ROOT / "tools/persistent/worker_typing_exceptions.txt"

KEYWORDS = {"and", "or", "not", "in", "if", "else", "elif", "for", "var", "return", "true", "false", "null", "self", "while", "is",
            "as", "continue", "break", "pass", "await", "func", "match", "const", "static", "super", "PI", "TAU", "INF", "NAN"}
CONVERT = {"int", "float", "bool", "str", "String", "StringName", "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Color",
           "absi", "absf", "mini", "maxi", "minf", "maxf", "clampi", "clampf", "floori", "ceili", "roundi", "floorf", "ceilf",
           "roundf", "sqrt", "pow", "sin", "cos", "abs", "floor", "ceil", "round", "len", "typeof", "is_instance_valid", "signi",
           "signf", "fposmod", "posmod", "wrapi", "wrapf", "lerpf", "deg_to_rad", "rad_to_deg", "is_finite", "is_nan", "hash"}
TYPED_ITERABLES = ("Packed", "Array[", "String")
BIN_OPS = ["**", "==", "!=", "<=", ">=", "<<", ">>", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<", ">", "+", "-", "*",
           "/", "%", "&", "|", "^"]
WORD_OPS = {"and", "or"}


# ---------------------------------------------------------------------------------------------------------------------------------
# the index

class Func:
    def __init__(self, path, name, start, lines, static):
        self.path, self.name, self.start, self.lines, self.static = path, name, start, lines, static   ## lines: [(lineno, text)]


def strip_comment(line):
    out, q = [], None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            out.append(c)
            if c == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
            out.append(c)
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out).rstrip()


def blank_strings(code):
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', code)


def indent_of(line):
    return len(line) - len(line.lstrip("\t"))


class Index:
    def __init__(self):
        self.files = sorted(f for f in glob.glob(str(ROOT / SCRIPTS / "**/*.gd"), recursive=True) if "/tools/" not in f)
        self.src = {}
        self.funcs = {}          ## (path, name) -> Func
        self.class_of = {}       ## path -> class_name
        self.by_class = {}       ## class_name -> path
        self.preload = {}        ## (path, alias) -> path
        self.members = {}        ## path -> {name: type}
        self.by_name = {}        ## func name -> [keys]
        for f in self.files:
            rel = os.path.relpath(f, ROOT)
            lines = open(f, encoding="utf-8").read().split("\n")
            self.src[rel] = lines
            self._scan(rel, lines)

    def _scan(self, rel, lines):
        members = {}
        cur = None
        for i, raw in enumerate(lines):
            line = raw.rstrip("\n")
            m = re.match(r"class_name (\w+)", line)
            if m:
                self.class_of[rel] = m.group(1)
                self.by_class[m.group(1)] = rel
            m = re.match(r'const (\w+)\s*=\s*preload\("res://(.+?\.gd)"\)', line)
            if m:
                self.preload[(rel, m.group(1))] = m.group(2)
            if line.strip() == "":
                if cur is not None:
                    cur.lines.append((i + 1, line))   ## a blank line does not end a function
                continue
            if not line.startswith(("\t", " ")):
                cur = None
                m = re.match(r"(static )?func (\w+)\s*\(", line)
                if m:
                    key = (rel, m.group(2))
                    cur = Func(rel, m.group(2), i + 1, [(i + 1, line)], bool(m.group(1)))
                    self.funcs[key] = cur
                    self.by_name.setdefault(m.group(2), []).append(key)
                    continue
                m = re.match(r"(?:@\w+(?:\(.*?\))?\s+)*(?:static )?var (\w+)\s*(?::\s*([\w\[\]]+))?\s*(:?=)?\s*(.*)", line)
                if m:
                    members[m.group(1)] = declared_type(m.group(2), m.group(3), m.group(4))
                m = re.match(r"const (\w+)\s*(?::\s*([\w\[\]]+))?\s*(:?=)\s*(.*)", line)
                if m:
                    members[m.group(1)] = declared_type(m.group(2), ":=", m.group(4))
            elif cur is not None:
                cur.lines.append((i + 1, line))
        self.members[rel] = members


def declared_type(annot, assign, rhs):
    if annot:
        return annot
    if assign == ":=":
        return infer(rhs or "")
    return "Variant"


def infer(rhs):
    rhs = rhs.strip()
    m = re.match(r"(\w+)\.new\(", rhs)
    if m:
        return m.group(1)
    m = re.match(r"(Packed\w+Array|Vector[234]i?|Color|Rect2i?|Transform[23]D|Basis|AABB|Plane|Quaternion)\(", rhs)
    if m:
        return m.group(1)
    if re.match(r"-?\d+\.\d*|-?\d*\.\d+", rhs):
        return "float"
    if re.match(r"-?\d+\b", rhs) or re.match(r"(int|len|floori|ceili|roundi|mini|maxi|clampi|absi)\(", rhs):
        return "int"
    if re.match(r"(float|sqrt|minf|maxf|clampf|absf|pow|sin|cos)\(", rhs):
        return "float"
    if re.match(r"(true|false|bool)\b", rhs):
        return "bool"
    if rhs.startswith('"') or re.match(r"(str|String)\(", rhs):
        return "String"
    if rhs.startswith("["):
        return "Array"
    if rhs.startswith("{"):
        return "Dictionary"
    m = re.match(r".*\bas (\w+(?:\[\w+\])?)$", rhs)
    if m:
        return m.group(1)
    return "inferred"   ## `:=` from an expression the analyzer types (the compiler refuses `:=` from a Variant)


def is_untyped(t):
    return t in (None, "Variant", "Array", "Dictionary")


# ---------------------------------------------------------------------------------------------------------------------------------
# operand classification

def split_top(expr, sep_words):
    """Index of the first top-level occurrence of any word in sep_words (outside brackets), or -1."""
    depth = 0
    for m in re.finditer(r"[\(\[\{]|[\)\]\}]|\b(\w+)\b", expr):
        tok = m.group(0)
        if tok in "([{":
            depth += 1
        elif tok in ")]}":
            depth -= 1
        elif depth == 0 and tok in sep_words:
            return m.start()
    return -1


def classify(expr, types):
    """None if the expression is typed for the compiler, else a short reason."""
    e = expr.strip()
    while e.startswith("(") and matching(e, 0) == len(e) - 1:
        e = e[1:-1].strip()
    if not e:
        return None
    i = split_top(e, {"if"})
    if i > 0:
        j = split_top(e[i + 2:], {"else"})
        if j >= 0:
            return classify(e[:i], types) or classify(e[i + 2 + j + 4:], types)
    if re.search(r"\bas\s+[A-Z]\w*(\[\w+\])?\s*$", e):
        return None
    if re.match(r'^-?[\d.]+(e-?\d+)?$|^""$|^(true|false|null)$|^0x[0-9a-fA-F]+$', e):
        return None
    if e.startswith("not ") or e.startswith("-"):
        return classify(e.split(" ", 1)[1] if e.startswith("not ") else e[1:], types)
    ## a chain: head ( '.' name | '(' args ')' | '[' index ']' )*
    m = re.match(r"([A-Za-z_]\w*)", e)
    if not m:
        return None   ## a literal array / dict / something we do not model: lenient
    head = m.group(1)
    pos = m.end()
    if pos < len(e) and e[pos] == "(":
        end = matching(e, pos)
        if head in CONVERT or head[0].isupper():
            cur_t = head if head[0].isupper() else "typed"
        else:
            cur_t = "call"
        pos = end + 1
    else:
        cur_t = types.get(head)
        if cur_t is None:
            if head[0].isupper():
                cur_t = "class"
            elif head in KEYWORDS:
                return None
            else:
                cur_t = "unknown"
    while pos < len(e):
        c = e[pos]
        if c == "[":
            end = matching(e, pos)
            if cur_t in ("Array", "Dictionary", "Variant"):
                return "an element of untyped %s `%s`" % (cur_t, e[:end + 1])
            if cur_t and cur_t.startswith("Array["):
                cur_t = cur_t[6:-1]
            else:
                cur_t = "typed"
            pos = end + 1
        elif c == ".":
            m2 = re.match(r"\.([A-Za-z_]\w*)", e[pos:])
            if not m2:
                return None
            name = m2.group(1)
            pos += m2.end()
            if pos < len(e) and e[pos] == "(":
                end = matching(e, pos)
                if name in ("get", "get_or_add") and cur_t in ("Dictionary", "Variant", "unknown"):
                    return "a `Dictionary.get()` result `%s`" % e[:end + 1]
                if cur_t == "Variant":
                    return "a call on untyped `%s`" % e[:pos - len(name) - 1]
                cur_t = "call"
                pos = end + 1
            else:
                if cur_t == "Variant":
                    return "a property of untyped `%s`" % e[:pos - len(name) - 1]
                cur_t = "typed"
        else:
            break
    if pos < len(e):
        return None   ## a sub-expression with its own operators: those are checked on their own
    if cur_t == "Variant":
        return "untyped `%s`" % e
    return None


def matching(s, i):
    pairs = {"(": ")", "[": "]", "{": "}"}
    close = pairs[s[i]]
    depth = 0
    q = None
    for j in range(i, len(s)):
        c = s[j]
        if q:
            if c == q:
                q = None
            continue
        if c in "\"'":
            q = c
        elif c == s[i]:
            depth += 1
        elif c == close:
            depth -= 1
            if depth == 0:
                return j
    return len(s) - 1


def operands(code):
    """Yields (left, right) operand strings of every binary operator, and (None, operand) of every `not` / unary minus."""
    s = code
    n = len(s)
    i = 0
    depth_q = None
    while i < n:
        c = s[i]
        if c in "\"'":
            j = s.find(c, i + 1)
            i = (j + 1) if j > 0 else n
            continue
        word = re.match(r"\b(and|or|not)\b", s[i:]) if (i == 0 or not (s[i - 1].isalnum() or s[i - 1] == "_")) else None
        if word:
            w = word.group(1)
            if w == "not":
                yield None, read_right(s, i + 3)
            else:
                yield read_left(s, i), read_right(s, i + len(w))
            i += len(w)
            continue
        op = None
        for o in BIN_OPS:
            if s.startswith(o, i):
                op = o
                break
        if op and not s.startswith("->", i) and not (op == "-" and s.startswith("->", i)):
            left = read_left(s, i)
            if op == "-" and (left is None or left.strip() == ""):
                yield None, read_right(s, i + 1)
            elif op in ("<", ">") and s[i - 1:i] == "-":
                pass
            elif left is not None:
                yield left, read_right(s, i + len(op))
            i += len(op)
            continue
        i += 1


STOP_LEFT = set(",(=[{:") | {"\t"}


def read_left(s, i):
    j = i - 1
    while j >= 0 and s[j] == " ":
        j -= 1
    end = j + 1
    while j >= 0:
        c = s[j]
        if c in ")]}":
            depth = 0
            k = j
            while k >= 0:
                if s[k] in ")]}":
                    depth += 1
                elif s[k] in "([{":
                    depth -= 1
                    if depth == 0:
                        break
                k -= 1
            j = k - 1
            continue
        if c.isalnum() or c in "_.":
            j -= 1
            continue
        if c == '"':
            k = s.rfind('"', 0, j)
            j = k - 1
            continue
        break
    left = s[j + 1:end].strip()
    if re.fullmatch(r"(and|or|not|in|if|else|return|elif|while|var|for)", left or ""):
        return ""
    return left


def read_right(s, i):
    j = i
    while j < len(s) and s[j] == " ":
        j += 1
    start = j
    if s[j:j + 4] == "not ":
        return s[j:j + 4] + read_right(s, j + 4)
    if j < len(s) and s[j] == "-":
        j += 1
    while j < len(s):
        c = s[j]
        if c in "([{":
            j = matching(s, j) + 1
            continue
        if c.isalnum() or c in "_.":
            j += 1
            continue
        if c == '"':
            k = s.find('"', j + 1)
            j = (k + 1) if k > 0 else len(s)
            continue
        break
    return s[start:j].strip()


# ---------------------------------------------------------------------------------------------------------------------------------
# scopes and reach

def param_types(sig):
    types = {}
    inner = sig[sig.find("(") + 1: sig.rfind(")")] if "(" in sig else ""
    for p in split_args(inner):
        m = re.match(r"\s*(\w+)\s*(?::\s*([\w\[\]]+))?\s*(:?=)?\s*(.*)", p)
        if m and m.group(1):
            if m.group(2):
                types[m.group(1)] = m.group(2)
            elif m.group(3) == ":=":
                types[m.group(1)] = infer(m.group(4))
            else:
                types[m.group(1)] = "Variant"
    return types


def split_args(s):
    out, depth, cur = [], 0, ""
    for c in s:
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += c
    if cur.strip():
        out.append(cur)
    return out


def local_types(lines, base):
    """Declared types of locals and loop variables, in order (a later declaration of the same name wins from its line on)."""
    per_line = {}
    t = dict(base)
    for n, raw in lines:
        code = blank_strings(strip_comment(raw))
        m = re.match(r"\s*var (\w+)\s*:\s*([\w\[\]]+)", code)
        if m:
            t[m.group(1)] = m.group(2)
        else:
            m = re.match(r"\s*var (\w+)\s*:=\s*(.*)", code)
            if m:
                t[m.group(1)] = infer(m.group(2))
            else:
                m = re.match(r"\s*var (\w+)\s*=", code)
                if m:
                    t[m.group(1)] = "Variant"
        m = re.match(r"\s*for (\w+)\s*:\s*([\w\[\]]+)\s+in\b", code)
        if m:
            t[m.group(1)] = m.group(2)
        else:
            m = re.match(r"\s*for (\w+)\s+in\s+(.*):\s*$", code)
            if m:
                t[m.group(1)] = iter_type(m.group(2), t)
        per_line[n] = dict(t)
    return per_line


def iter_type(src, t):
    s = src.strip()
    if s.startswith("range("):
        return "int"
    m = re.search(r"\bas (Packed\w+Array)\)?$", s)
    if m:
        return "int"
    m = re.match(r"\(?([A-Za-z_]\w*)(\.keys\(\)|\.values\(\))?\)?$", s)
    if m:
        bt = t.get(m.group(1)) or ""
        if m.group(2):
            return "Variant"
        if bt.startswith("Packed") or bt == "String":
            return "typed"
        if bt.startswith("Array["):
            return bt[6:-1]
        return "Variant"
    return "Variant"


class Checker:
    def __init__(self, idx):
        self.idx = idx
        self.roots = []          ## (label, path, enclosing Func or None, body lines, extra types)
        self.reach = {}          ## key -> reason

    # --- roots ----------------------------------------------------------------------------------------------------------------------
    def find_roots(self):
        for key, f in self.idx.funcs.items():
            for k, (n, raw) in enumerate(f.lines):
                code = strip_comment(raw)
                m = re.search(r"WorkerThreadPool\.add_(group_)?task\(", code)
                if not m:
                    continue
                arg = code[m.end():]
                ## an argument split over lines: join until the first top-level comma
                j = k + 1
                while split_top_comma(arg) < 0 and j < len(f.lines):
                    arg += "\n" + strip_comment(f.lines[j][1])
                    j += 1
                first = arg[:split_top_comma(arg)] if split_top_comma(arg) >= 0 else arg
                self._root_from(f, k, n, first.strip())

    def _root_from(self, f, k, n, first):
        label = "%s:%d" % (f.path, n)
        if first.startswith("func"):
            self._lambda_root(f, k, label, first)
            return
        m = re.match(r"([A-Za-z_]\w*)(\.bind\(.*\))?$", first.replace("\n", " ").strip())
        if not m:
            print("[WORKER-TYPING] %s: cannot read the task callable `%s`" % (label, first[:60]))
            return
        name = m.group(1)
        ## a lambda held in a local of the enclosing function?
        for kk, (nn, raw) in enumerate(f.lines):
            mm = re.match(r"\s*var %s\s*:?=\s*(func.*)" % re.escape(name), strip_comment(raw))
            if mm:
                self._lambda_root(f, kk, "%s (lambda `%s`)" % (label, name), mm.group(1))
                return
        key = (f.path, name)
        if key in self.idx.funcs:
            self.reach_from(key, label)
        else:
            print("[WORKER-TYPING] %s: the task callable `%s` is not a function of this file" % (label, name))

    def _lambda_root(self, f, k, label, head):
        """The lambda's body: the rest of its line, or the lines indented deeper than the one it starts on."""
        start_line = f.lines[k][1]
        base_indent = indent_of(start_line)
        params = param_types(head[:head.find(")") + 1] if ")" in head else "")
        enclosing = local_types(f.lines, {**self.idx.members[f.path], **param_types(f.lines[0][1])})
        types = dict(enclosing.get(f.lines[k][0], {}))
        types.update(params)
        colon = head.find(":", head.find(")"))
        body = []
        inline = head[colon + 1:].strip() if colon >= 0 else ""
        if inline:
            body.append((f.lines[k][0], "\t" * (base_indent + 1) + inline))
        for n, raw in f.lines[k + 1:]:
            if raw.strip() == "":
                continue
            if indent_of(raw) <= base_indent:
                break
            body.append((n, raw))
        self.roots.append((label, f.path, body, types))
        for callee in self.calls(f.path, body, types):
            self.reach_from(callee, label)

    # --- reach ----------------------------------------------------------------------------------------------------------------------
    def reach_from(self, key, why):
        todo = [(key, why)]
        while todo:
            k, w = todo.pop()
            if k in self.reach or k not in self.idx.funcs:
                continue
            self.reach[k] = w
            f = self.idx.funcs[k]
            types = {**self.idx.members[f.path], **param_types(f.lines[0][1])}
            per = local_types(f.lines, types)
            for n, raw in f.lines[1:]:
                for c in self.calls(f.path, [(n, raw)], per.get(n, types)):
                    todo.append((c, w))

    def calls(self, path, lines, types):
        out = []
        for n, raw in lines:
            code = blank_strings(strip_comment(raw))
            for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", code):
                if (path, m.group(1)) in self.idx.funcs:
                    out.append((path, m.group(1)))
            ## `(x as Type).method(`, `Type.new(` -> `_init`
            for m in re.finditer(r"\bas ([A-Z]\w*)\)\.([A-Za-z_]\w*)\s*\(", code):
                target = self.idx.by_class.get(m.group(1))
                if target and (target, m.group(2)) in self.idx.funcs:
                    out.append((target, m.group(2)))
            for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\.new\s*\(", code):
                target = self.idx.by_class.get(m.group(1)) or self.idx.preload.get((path, m.group(1)))
                if target and (target, "_init") in self.idx.funcs:
                    out.append((target, "_init"))
            for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*\(", code):
                recv, meth = m.group(1), m.group(2)
                target = None
                if recv in self.idx.by_class:
                    target = self.idx.by_class[recv]
                elif (path, recv) in self.idx.preload:
                    target = self.idx.preload[(path, recv)]
                else:
                    t = (types.get(recv) or "").replace("Array[", "").rstrip("]")
                    if t in self.idx.by_class:
                        target = self.idx.by_class[t]
                if target and (target, meth) in self.idx.funcs:
                    out.append((target, meth))
                elif target is None and types.get(recv) in (None, "Variant", "unknown", "inferred"):
                    cands = self.idx.by_name.get(meth, [])
                    if len(cands) == 1:
                        out.append(cands[0])
        return out

    # --- the rule -------------------------------------------------------------------------------------------------------------------
    def hazards(self):
        found = []
        for label, path, body, types in self.roots:
            per = local_types(body, types)
            for n, raw in body:
                found += [(path, n, "<lambda %s>" % label, why, raw.strip()) for why in self.line_hazards(raw, per.get(n, types))]
        for key in sorted(self.reach):
            f = self.idx.funcs[key]
            types = {**self.idx.members[f.path], **param_types(f.lines[0][1])}
            per = local_types(f.lines, types)
            for n, raw in f.lines[1:]:
                found += [(f.path, n, f.name, why, raw.strip()) for why in self.line_hazards(raw, per.get(n, types))]
        return found

    def line_hazards(self, raw, types):
        code = blank_strings(strip_comment(raw))
        if not code.strip():
            return []
        if re.match(r"\s*match\b", code):
            return ["a `match` (use an `if` chain)"]
        stripped = code.strip()
        m = re.match(r"(?:var \w+\s*(?::\s*[\w\[\]]+)?\s*:?=|for \w+(?:\s*:\s*[\w\[\]]+)?\s+in|return|if|elif|while)\s*(.*)", stripped)
        expr_part = m.group(1) if m else stripped
        if not m:
            ## an assignment: what is assigned (and a compound assignment's target) is the expression
            a = re.match(r"(.+?)\s*([+\-*/%&|^]?=)(?!=)\s*(.*)", stripped)
            if a and a.group(2) != "=":
                expr_part = "%s %s %s" % (a.group(1), a.group(2)[0], a.group(3))
            elif a:
                expr_part = a.group(3)
        out = []
        for left, right in operands(expr_part):
            for side in (left, right):
                if not side:
                    continue
                why = classify(side, types)
                if why:
                    out.append(why)
        return sorted(set(out))


def split_top_comma(s):
    depth = 0
    q = None
    for i, c in enumerate(s):
        if q:
            if c == q:
                q = None
            continue
        if c in "\"'":
            q = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return i
            depth -= 1
        elif c == "," and depth == 0:
            return i
    return -1


def load_exceptions():
    ex = set()
    if not EXCEPTIONS.exists():
        return ex
    for line in EXCEPTIONS.read_text(encoding="utf-8").split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in line.split("  # ")[0].split(" | ")]
        if len(parts) >= 3:
            ex.add((parts[0], parts[1], parts[2]))
    return ex


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-roots", action="store_true")
    ap.add_argument("--list-reach", action="store_true")
    args = ap.parse_args()
    idx = Index()
    ck = Checker(idx)
    ck.find_roots()
    if args.list_roots:
        for label, path, body, _ in ck.roots:
            print("[WORKER-TYPING] lambda root %s (%d line(s))" % (label, len(body)))
    if args.list_reach:
        for k in sorted(ck.reach):
            print("[WORKER-TYPING] reached %s:%s (from %s)" % (k[0], k[1], ck.reach[k]))
    ex = load_exceptions()
    bad = [h for h in ck.hazards() if (h[0], h[2], h[4]) not in ex]
    used = {(h[0], h[2], h[4]) for h in ck.hazards()}
    for path, n, fn, why, code in bad:
        print("[WORKER-TYPING] %s:%d %s | %s | %s" % (path, n, fn, why, code[:140]))
    stale = ex - used
    for s in sorted(stale):
        print("[WORKER-TYPING] stale exception (matches nothing now): %s | %s | %s" % s)
    print("[WORKER-TYPING] %d worker root(s) (%d lambda), %d function(s) reached, %d hazard(s), %d exception(s)"
          % (len(ck.roots) + len({v for v in ck.reach.values()}), len(ck.roots), len(ck.reach), len(bad), len(ex)))
    if bad or stale:
        print("[WORKER-TYPING] FAIL — type the operand, convert it (int()/float()/bool()), or replace the match with an if chain; "
              "a reviewed false positive goes in tools/persistent/worker_typing_exceptions.txt")
        return 1
    print("[WORKER-TYPING] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
