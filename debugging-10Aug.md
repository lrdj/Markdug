Two things to check, in order:

1. Isolate it with a trivial test (2 minutes, no AppleScript involved):

/usr/libexec/PlistBuddy -c "Set :actions:0:action:ActionParameters:COMMAND_STRING 'date >> ~/Desktop/markdug-test.txt'" ~/Library/Services/Toggle Markdug.workflow/Contents/document.wflow

Then click Finder → Services → Toggle Markdug again.

- File appears on Desktop → Run Shell Script execution works fine via
Services; the AppleScript/Finder-selection call specifically is what's blocked
(Automation permission theory confirmed).
- Nothing appears → the Run Shell Script action isn't executing at all via
this path, which is a more fundamental block (possibly Gatekeeper refusing to
run script content from an unsigned/downloaded Automator bundle on this
locked-down account).

Afterwards, restore the real script with ./install-trigger.sh from the repo.

2. Check Console.app while you click it — Applications → Utilities → Console,
select your Mac in the sidebar, click Toggle Markdug in Finder's Services
menu, and look for anything mentioning "not allowed to send Apple events,"
"TCC," "denied," or "sandbox" around that moment.

Let me know what the test file shows — that tells us which of the two problems
we're actually dealing with.
