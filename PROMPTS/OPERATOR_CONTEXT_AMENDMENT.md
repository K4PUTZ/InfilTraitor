# OPERATOR_CONTEXT.md — Amendment: Evidence & Reporting Discipline

**Purpose:** consolidate everything the BAKE/MAPFILE/BLOCK sessions revealed about how completion reports go wrong, into permanent, general rules — so these don't need restating in every individual prompt, and so the architect isn't the last line of defense catching them after the fact.

**Where this goes:** insert as a new top-level section in `tools/persistent/OPERATOR_CONTEXT.md`, immediately after `## Verification Protocol` and before `## Architecture — Inviolable Rules`. Leave the existing Verification Protocol section as-is (items 1–5 are still correct); this is additive, not a replacement.

**Instruction to whoever applies this:** paste the section below verbatim. Do not summarize it, shorten it, or "improve" the phrasing — it's deliberately explicit because implicit versions of these rules have already been under-followed once each.

---

```markdown
## Evidence & Reporting Discipline

These rules exist because every one of them was violated at least once in this
project's history before being written down. They are not hypothetical.

### 1. The one-line summary is itself a claim, and needs its own evidence

"All N criteria pass" is a specific, falsifiable statement. Before writing it:
re-read your own completion report and confirm **every single criterion**
has a pasted, literal, executed transcript directly supporting it — not a
reasoned expectation, not "should work," not a narrative description of what
the code does.

If even one criterion is deferred, assumed, simulated, or measured
indirectly, **the summary must say so explicitly** — e.g. "6 of 8 criteria
measured with real output; 2 deferred (list them, list why)." Never round a
mixed result up to "complete" or "all pass." A summary that oversells what
the report body supports is a defect in itself, independent of whether the
underlying code is correct.

### 2. No silent substitution of an easier test

If an acceptance test specified in the prompt can't be executed as written
(missing tool, wrong environment, awkward setup), you may substitute a
different test — but you must **say so explicitly**, explain why the
original couldn't run, and mark the original criterion as still unverified.
Silently swapping in a synthetic/simpler case and reporting it as if it
satisfied the original requirement is the single most common failure mode
seen so far.

### 3. Red-before-green is not optional when fixing a specific reported bug

If you're fixing a bug that has a concrete, observed symptom (an error
message, a wrong value, a specific reproduction), your evidence must include
that **exact symptom reproducing** before your fix and **gone** after —
using the real bug, not a stand-in error you constructed for convenience.
If the real bug genuinely can't be reproduced in your environment, say so
and explain what you verified instead; don't substitute a different failure
case and imply it's the same proof.

### 4. Exclusions and skip-lists need a named, specific justification

Any filter that excludes files, cases, or paths from a validation/test tool
— by extension, naming pattern, directory, or category — must be justified
by the **exact observed error for a specific instance**, pasted in the
report. "Files matching X probably need Y context" is a guess, not a
justification, even if it sounds plausible. Before shipping any exclusion,
explicitly check: does this exclusion cover the exact case the tool exists
to catch? If the tool was built in response to a specific known bug, run it
against that bug with the exclusion in place and confirm it still catches it
— if the exclusion would hide the motivating bug, the exclusion is wrong,
no matter how reasonable its rationale sounds.

### 5. Verify the real vocabulary before writing any bridge or translator

Before writing code that adapts one data shape into another — a file schema
into a runtime spec, one internal format into a different consumer's
expected format, a new section into an existing pipeline — **read the
actual consuming code's real field names and shapes directly** (grep the
literal `.get("field", ...)` calls, read the actual function signature).
Do not assume two systems that seem to describe the same concept use the
same field names, nesting, or types. Report the exact shapes found, even
when it feels redundant, because assumed compatibility between two
independently-evolved formats has been wrong every time it wasn't checked
first in this project.

### 6. Archived completion reports must match the final repo state, not a draft

Before archiving a completion report (or marking a prompt fully done),
re-verify every claim in it against the **current** state of the repo, not
the state at the time each paragraph was drafted. If integration steps
finished after most of the report was written, update the report — don't
leave "(pending)" language for things that are actually done, and don't
leave confident-sounding language for things that stayed undone. A report
that under-claims is a smaller problem than one that over-claims, but both
mean the archived record can't be trusted at face value, which defeats the
point of archiving it.

### 7. When something genuinely can't be verified from where you're standing, say that plainly

Not every claim can be executed and captured in every environment. When
that's the case, the honest report is: "Not executable here; recommend
[specific manual check]" — not a confident PASS based on code reading, and
not silence. Code-reading-based confidence and execution-based confidence
are different things and must be labeled differently every time.

### Self-check before writing "✅ Complete" anywhere

Walk your own completion report criterion by criterion. For each one marked
✅: is there a pasted, literal, executed transcript immediately above it in
the report? If not, relabel it — in the report **and** in whatever summary
gets relayed onward — as DEFERRED, ASSUMED, or SIMULATED, with one sentence
on why and what would be needed to close it for real. This costs a few
minutes and catches most of what an external reviewer would otherwise have
to catch later, at higher cost to everyone.
```

---

*This amendment itself should be archived once applied — treat it like any other prompt: confirm insertion, paste the resulting section of the file to prove it landed correctly, done.*
