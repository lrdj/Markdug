# Markdug — Keyboard Maestro trigger investigation (17 May 2026)

## Symptom reported

On the M4 machine (macOS 15.7.3), pressing ⌥Space on a `.md` file no longer
produced the nice rendered Markdug window. Instead a **full-screen, terminal-like
window** appeared (black background, white text) with a button at the top right
labelled **"open markdown editor"**. The identical repo on the other machine
worked fine.

## Diagnosis

The repo and the installed app were both **healthy**. The fault was the
**Keyboard Maestro trigger**, not Markdug.

Evidence gathered:

| Link in the chain | Finding |
|---|---|
| KM macro config | Correct — ⌥Space → Execute `~/Sites/Markdug/km-macro.sh` asynchronously |
| `km-macro.sh` | Correct — toggles, reads Finder selection, launches the app binary |
| `/Applications/Markdug.app` binary | Current build (22 Feb 2026), contains `Open in Sublime` / `openInSublime`, `marked.min.js` + highlight.js + CSS + icon all present in Resources |
| `build.sh` swiftc target | `arm64-apple-macosx15.0` — correct for this M4 / 15.7.3 machine |

The string **"open markdown editor"** appears **nowhere** in this codebase, so
the black full-screen window was a *different application* opening the `.md`
file — not Markdug.

### Root cause

The Keyboard Maestro **trial had lapsed**. When the KM trial/licence lapses,
the **KM Engine stops executing macros**. So ⌥Space never ran `km-macro.sh`,
Markdug was never launched, and the `.md` file fell through to whatever other
app handled it (a generic Markdown/text viewer).

The other machine kept working because its KM trial/licence was still active.

### Resolution (confirmed working)

Quitting Keyboard Maestro, restarting it, clicking **Run** in the KM UI, then
retrying ⌥Space — **worked**. This confirms the script, macro, and app are all
fine; only the KM Engine state was the problem.

## Recommendations

### 1. Treat the KM Engine as the prime suspect for this symptom

If ⌥Space ever opens the "wrong app" again, **do not debug the code first**.
Check, in order:

1. Is the Keyboard Maestro menu-bar icon present? No icon ⇒ Engine not running
   ⇒ no macros fire.
2. Has the trial/licence lapsed? The recurring "Continue Trial" popup means
   you're on borrowed time every session.
3. Quit & relaunch Keyboard Maestro; click **Run** on the "Markdug
   integration" macro to re-arm.

Definitive app test (bypasses KM entirely):

```bash
/Applications/Markdug.app/Contents/MacOS/Markdug ~/Sites/Markdug/README.md
```

A clean ~900×700 rendered window ⇒ app is fine, fault is the trigger.

### 2. Resolve the trial properly

Either buy/enter a Keyboard Maestro licence, or reinstall the trial cleanly.
The repeating popup is the early-warning sign of this exact failure.

### 3. (Optional) Make the trigger KM-independent

The whole dependency is a single hotkey calling `km-macro.sh`. Lower-risk
alternatives that remove the KM single point of failure:

- **macOS Shortcuts / Automator Quick Action** — a Finder service that runs
  `km-macro.sh` against the selected file, bound to a keyboard shortcut in
  System Settings → Keyboard → Keyboard Shortcuts → Services. Free, built in.
- **A tiny `launchd` agent + a hotkey daemon** (e.g. `skhd`) — system-wide
  hotkey calling the same script. Free, scriptable, version-controllable.
- **Raycast / Alfred script command** — if either is already installed, a
  one-line script command wrapping `km-macro.sh`.

All three call the *same* `km-macro.sh`, so the existing logic is reused
unchanged. Recommended next step if KM licensing becomes a recurring nuisance.

## Status

- No code changes required.
- Repo, build script, macro script, and installed app all verified healthy.
- Issue was environmental (KM Engine dormant after trial lapse) and is resolved.
