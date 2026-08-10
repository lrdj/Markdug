# Installing Markdug on a standard (no-admin) account

This is for a machine where you're logged in as a standard user — no root, no
admin password, no Homebrew, no LLM to hand-hold the steps. Follow this in
order. Nothing here needs `sudo` or an admin password.

---

## 0. Before downloading anything — check the one real blocker

Open Terminal and run:

```bash
swift --version
```

If that prints a `Target:` line, you're fine — Xcode Command Line Tools are
already on the machine, and every step below will work.

If instead a dialog pops up offering to install Command Line Developer Tools,
**stop and check with whoever manages the machine first.** That installer
sometimes needs admin approval depending on how the Mac is locked down, and if
it's blocked, nothing here can compile. This is the one dependency that
couldn't be made root-free — Markdug needs the Swift compiler, and the Swift
compiler comes from Xcode Command Line Tools.

---

## 1. Get the repo — browser ZIP, not `git clone`

`git clone` over HTTPS would need a personal access token set up first, which
is extra friction for no benefit here. Instead:

1. Log into github.com in Safari or Chrome (you already have access to the
   private repo)
2. Green **Code** button → **Download ZIP**
3. Double-click the downloaded `.zip` in Finder — it extracts to a folder
   like `Markdug-main`

---

## 2. Open Terminal in that folder

```bash
cd ~/Downloads/Markdug-main
chmod +x build.sh install-trigger.sh km-macro.sh
```

(ZIP downloads don't preserve the executable bit, so this step is required
even though the same files were already executable in the repo.)

---

## 3. Check the Swift target line matches your macOS version

```bash
swift --version   # note the Target: line, e.g. arm64-apple-macosx15.0
```

Open `build.sh` in TextEdit (or `nano build.sh`) and check the two `-target`
lines near the top match what you just saw. Edit and save if not — this is
the most common reason the app window silently fails to appear.

---

## 4. Build and install

Everything installs inside your home folder — no `sudo`, ever.

```bash
./build.sh
```

Watch for the final `✅ Markdug installed!` message. Test it:

```bash
mdug ~/Downloads/Markdug-main/README.md
```

If you get `mdug: command not found`, close and reopen Terminal — the script
just added `~/.local/bin` to your `PATH` — then retry.

**If a window doesn't appear, or you see "can't be opened because it's from
an unidentified developer":** go to `~/Applications` in Finder, right-click
`Markdug.app` → **Open** → **Open anyway**. One-time only, no password
needed — this is Gatekeeper flagging your own local build as unsigned, not a
permissions problem.

---

## 5. Install the hotkey

```bash
./install-trigger.sh
```

Then, as it prints:

1. **System Settings → Keyboard → Keyboard Shortcuts… → Services**
2. Find **Toggle Markdug** under **General**
3. Double-click its shortcut column and press **⌥Space**

No admin password needed — assigning a keyboard shortcut to a Service is a
standard per-user preference, not a privileged action.

---

## 6. Test it for real

Select a `.md` file in Finder, press **⌥Space**. Markdug should open. Press
**⌥Space** again — it should close.

---

## If something doesn't work

- **`swift`/`swiftc` not found, or CLT install is blocked** — see step 0.
  This is the only step that can require someone with admin rights.
- **Window never appears** — almost always the target-version mismatch in
  step 3. Recheck `swift --version` and `build.sh`.
- **⌥Space does nothing** —
  - `ls ~/Library/Services` should list `Toggle Markdug.workflow`. If not,
    re-run `./install-trigger.sh`.
  - Check the shortcut is actually bound: System Settings → Keyboard →
    Keyboard Shortcuts… → Services → General → **Toggle Markdug**.
  - Test the trigger directly, bypassing the hotkey:
    `automator ~/Library/Services/Toggle\ Markdug.workflow` — if that doesn't
    launch Markdug (with a `.md` file selected in Finder first), the problem
    is in `km-macro.sh` or the app, not the hotkey binding.
- **"Open in Sublime" button does nothing** — it just needs Sublime Text
  installed somewhere Spotlight can find it (`/Applications` or
  `~/Applications` both work). No CLI tool or `PATH` setup required.

Nothing in this install path touches `/Applications`, `/usr/local/bin`,
Homebrew, or the Accessibility permission list — only step 0's Command Line
Tools check depends on anything outside your own account.
