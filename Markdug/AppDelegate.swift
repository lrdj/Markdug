import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: NSWindow?
    var webView: WKWebView?
    var currentFilePath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Markdug"
        win.delegate = self
        win.titlebarAppearsTransparent = false

        // WebView
        let wv = WKWebView(frame: win.contentView!.bounds)
        wv.autoresizingMask = [.width, .height]
        win.contentView!.addSubview(wv)

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
        self.webView = wv

        // Add pill button inline in title bar — no extra height
        addSublimeButton(to: win)

        // Escape or Cmd+W quits
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w") {
                NSApp.terminate(nil)
            }
            return event
        }

        let args = CommandLine.arguments
        if args.count > 1 {
            openFile(path: args[1])
        } else {
            wv.loadHTMLString("""
                <html><body style="font-family:system-ui;padding:60px;color:#999;text-align:center;">
                <h2 style="margin-top:120px;">Markdug</h2>
                <p>Run <code>mdug yourfile.md</code> to open a file.</p>
                </body></html>
            """, baseURL: nil)
        }
    }

    func addSublimeButton(to win: NSWindow) {
        guard let titlebarView = win.standardWindowButton(.closeButton)?.superview else { return }

        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 120, height: 22))
        button.title = "Open in Sublime"
        button.bezelStyle = .roundRect
        button.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        button.target = self
        button.action = #selector(openInSublime)
        button.autoresizingMask = [.minXMargin]

        titlebarView.addSubview(button)

        // Position to the right, vertically centred in title bar
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: titlebarView.trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor)
        ])
    }

    @objc func openInSublime() {
        guard let path = currentFilePath else { return }
        let task = Process()
        task.launchPath = "/usr/local/bin/subl"
        task.arguments = [path]
        try? task.run()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func openFile(path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            showError("File not found: \(expandedPath)"); return
        }
        guard let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            showError("Could not read: \(expandedPath)"); return
        }

        currentFilePath = expandedPath
        let filename = URL(fileURLWithPath: expandedPath).lastPathComponent
        window?.title = filename

        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let markedSrc: String
        if let p = Bundle.main.path(forResource: "marked.min", ofType: "js"),
           let js = try? String(contentsOfFile: p, encoding: .utf8) {
            markedSrc = js
        } else {
            markedSrc = "window.marked={parse:s=>'<pre>'+s+'</pre>'};"
        }

        let html = """
        <!DOCTYPE html><html><head><meta charset="UTF-8">
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:16px;line-height:1.6;max-width:820px;margin:0 auto;padding:40px 32px 80px;color:#24292f}
        @media(prefers-color-scheme:dark){body{background:#0d1117;color:#e6edf3}code{background:#161b22}pre{background:#161b22;border-color:#30363d}blockquote{border-color:#3d444d;color:#8b949e}table td,table th{border-color:#30363d}table tr:nth-child(2n){background:#161b22}a{color:#58a6ff}}
        h1,h2,h3,h4{font-weight:600;line-height:1.25;margin:24px 0 16px}
        h1{font-size:2em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
        h2{font-size:1.5em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
        p{margin-bottom:16px}a{color:#0969da}
        code{font-family:'SF Mono',Menlo,monospace;font-size:85%;background:#f6f8fa;padding:.2em .4em;border-radius:4px}
        pre{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:16px;overflow:auto}
        pre code{background:none;padding:0}
        blockquote{padding:0 1em;color:#656d76;border-left:4px solid #d0d7de;margin:0 0 16px}
        ul,ol{padding-left:2em;margin-bottom:16px}
        table{border-collapse:collapse;width:100%;margin-bottom:16px}
        table td,table th{padding:6px 13px;border:1px solid #d0d7de}
        table th{font-weight:600;background:#f6f8fa}
        table tr:nth-child(2n){background:#f6f8fa}
        img{max-width:100%}hr{height:4px;background:#d0d7de;border:0;border-radius:2px;margin:24px 0}
        </style></head><body>
        <script>\(markedSrc)</script>
        <div id="c"></div>
        <script>document.getElementById('c').innerHTML=marked.parse(`\(escaped)`);</script>
        </body></html>
        """

        let baseURL = URL(fileURLWithPath: expandedPath).deletingLastPathComponent()
        webView?.loadHTMLString(html, baseURL: baseURL)
    }

    func showError(_ msg: String) {
        webView?.loadHTMLString("<html><body style='font-family:system-ui;padding:40px;color:#c00'><h2>Error</h2><p>\(msg)</p></body></html>", baseURL: nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
