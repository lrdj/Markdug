#!/bin/bash
# Keyboard Maestro macro script for Markdug
# Set output to: Asynchronously

# If Markdug is already running, quit it (toggle behaviour)
if pgrep -x "Markdug" > /dev/null; then
    pkill -x "Markdug"
    exit 0
fi

# Get selected file from Finder
FILEPATH=$(osascript -e '
tell application "Finder"
    set sel to selection
    if sel is {} then
        return ""
    else
        return POSIX path of (item 1 of sel as alias)
    end if
end tell
')

if [ -z "$FILEPATH" ]; then
    osascript -e 'display notification "No file selected in Finder" with title "Markdug"'
    exit 0
fi

case "$FILEPATH" in
    *.md|*.markdown|*.mdx|*.mdown)
        /Applications/Markdug.app/Contents/MacOS/Markdug "$FILEPATH" &
        ;;
    *)
        osascript -e "display notification \"Not a Markdown file\" with title \"Markdug\""
        ;;
esac
