import AppKit

class DraggableImageView: NSImageView {
    var initialMouseLocation: NSPoint = .zero
    var onDrag: ((CGFloat) -> Void)?

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
        onDrag?(newOrigin.y)
    }
}

class SpeechBubble: NSView {
    var message: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bubbleRect = NSRect(x: 0, y: 10, width: bounds.width, height: bounds.height - 10)
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)

        let tailPath = NSBezierPath()
        tailPath.move(to: NSPoint(x: bounds.width / 2 - 8, y: 10))
        tailPath.line(to: NSPoint(x: bounds.width / 2, y: 0))
        tailPath.line(to: NSPoint(x: bounds.width / 2 + 8, y: 10))
        tailPath.close()

        NSColor.white.setFill()
        path.fill()
        tailPath.fill()

        NSColor.gray.setStroke()
        path.lineWidth = 1
        path.stroke()
        tailPath.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        let textRect = bubbleRect.insetBy(dx: 8, dy: 6)
        message.draw(in: textRect, withAttributes: attrs)
    }
}

struct RemoteConfig: Codable {
    var name: String
    var host: String
    var user: String
    var keyPath: String
    var enabled: Bool
}

struct MaxwellConfig: Codable {
    var remotes: [RemoteConfig]

    static let configPath = NSString(string: "~/.maxwell/config.json").expandingTildeInPath

    static func load() -> MaxwellConfig {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(MaxwellConfig.self, from: data) else {
            return MaxwellConfig(remotes: [])
        }
        return config
    }

    func save() {
        let dir = NSString(string: "~/.maxwell").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: URL(fileURLWithPath: MaxwellConfig.configPath))
        }
    }
}

class SettingsWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var window: NSWindow?
    var tableView: NSTableView!
    var config: MaxwellConfig
    var onConfigChanged: (() -> Void)?

    override init() {
        config = MaxwellConfig.load()
        super.init()
    }

    func show() {
        if window == nil {
            setupWindow()
        }
        config = MaxwellConfig.load()
        tableView.reloadData()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Maxwell Settings"
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 350))

        let label = NSTextField(labelWithString: "Remote SSH Servers")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 310, width: 200, height: 20)
        contentView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 100, width: 460, height: 200))
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 24

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 80
        tableView.addTableColumn(nameCol)

        let hostCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        hostCol.title = "Host"
        hostCol.width = 120
        tableView.addTableColumn(hostCol)

        let userCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("user"))
        userCol.title = "User"
        userCol.width = 80
        tableView.addTableColumn(userCol)

        let keyCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("keyPath"))
        keyCol.title = "SSH Key Path"
        keyCol.width = 140
        tableView.addTableColumn(keyCol)

        let enabledCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledCol.title = "On"
        enabledCol.width = 30
        tableView.addTableColumn(enabledCol)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 20, y: 60, width: 80, height: 30))
        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addRemote)
        contentView.addSubview(addButton)

        let removeButton = NSButton(frame: NSRect(x: 110, y: 60, width: 80, height: 30))
        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeRemote)
        contentView.addSubview(removeButton)

        let saveButton = NSButton(frame: NSRect(x: 380, y: 20, width: 100, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        contentView.addSubview(saveButton)

        w.contentView = contentView
        window = w
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return config.remotes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < config.remotes.count else { return nil }
        let remote = config.remotes[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        if identifier == "enabled" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            checkbox.state = remote.enabled ? .on : .off
            checkbox.tag = row
            return checkbox
        }

        let textField = NSTextField()
        textField.isBordered = true
        textField.bezelStyle = .squareBezel
        textField.isEditable = true
        textField.delegate = self
        textField.tag = row

        switch identifier {
        case "name": textField.stringValue = remote.name
        case "host": textField.stringValue = remote.host
        case "user": textField.stringValue = remote.user
        case "keyPath": textField.stringValue = remote.keyPath
        default: break
        }

        textField.identifier = tableColumn?.identifier
        return textField
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = sender.tag
        if row < config.remotes.count {
            config.remotes[row].enabled = sender.state == .on
        }
    }

    @objc private func addRemote() {
        config.remotes.append(RemoteConfig(name: "new", host: "", user: "", keyPath: "~/.ssh/id_rsa", enabled: true))
        tableView.reloadData()
    }

    @objc private func removeRemote() {
        let row = tableView.selectedRow
        if row >= 0 && row < config.remotes.count {
            config.remotes.remove(at: row)
            tableView.reloadData()
        }
    }

    @objc private func saveConfig() {
        config.save()
        onConfigChanged?()
        window?.close()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let identifier = textField.identifier?.rawValue else { return }
        let row = textField.tag
        guard row < config.remotes.count else { return }

        switch identifier {
        case "name": config.remotes[row].name = textField.stringValue
        case "host": config.remotes[row].host = textField.stringValue
        case "user": config.remotes[row].user = textField.stringValue
        case "keyPath": config.remotes[row].keyPath = textField.stringValue
        default: break
        }
    }
}

class HoverView: NSView {
    var closeButton: NSButton!
    var increaseButton: NSButton!
    var decreaseButton: NSButton!
    var settingsButton: NSButton!
    var trackingArea: NSTrackingArea?
    var aspectRatio: CGFloat = 1.0
    var bubbleWindows: [NSWindow] = []
    var onSettingsClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        aspectRatio = frame.width / frame.height
        setupButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButtons()
    }

    private func createButton(symbolName: String, x: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: frame.height - 24, width: 20, height: 20))
        button.bezelStyle = .circular
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        button.layer?.cornerRadius = 10
        button.isHidden = true
        button.autoresizingMask = [.minXMargin, .minYMargin]
        return button
    }

    private func setupButtons() {
        closeButton = createButton(symbolName: "xmark.circle.fill", x: frame.width - 24)
        closeButton.target = NSApplication.shared
        closeButton.action = #selector(NSApplication.terminate(_:))
        addSubview(closeButton)

        increaseButton = createButton(symbolName: "plus.circle.fill", x: frame.width - 48)
        increaseButton.target = self
        increaseButton.action = #selector(increaseSize)
        addSubview(increaseButton)

        decreaseButton = createButton(symbolName: "minus.circle.fill", x: frame.width - 72)
        decreaseButton.target = self
        decreaseButton.action = #selector(decreaseSize)
        addSubview(decreaseButton)

        settingsButton = createButton(symbolName: "gearshape.fill", x: frame.width - 96)
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        addSubview(settingsButton)
    }

    @objc private func openSettings() {
        onSettingsClick?()
    }

    @objc private func increaseSize() {
        resizeWindow(scale: 1.2)
    }

    @objc private func decreaseSize() {
        resizeWindow(scale: 0.8)
    }

    private func resizeWindow(scale: CGFloat) {
        guard let window = self.window else { return }
        let currentFrame = window.frame
        let newWidth = currentFrame.width * scale
        let newHeight = newWidth / aspectRatio
        let newX = currentFrame.origin.x - (newWidth - currentFrame.width) / 2
        let newY = currentFrame.origin.y - (newHeight - currentFrame.height) / 2
        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
        window.setFrame(newFrame, display: true, animate: true)
    }

    func showBubbles(messages: [String]) {
        hideBubbles()

        guard let mainWindow = self.window else { return }

        let bubbleWidth: CGFloat = 180
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5

        for (index, message) in messages.enumerated() {
            let yOffset = CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset

            let bubbleWindow = NSWindow(
                contentRect: NSRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            bubbleWindow.isOpaque = false
            bubbleWindow.backgroundColor = .clear
            bubbleWindow.hasShadow = false
            bubbleWindow.level = .floating
            bubbleWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

            let bubble = SpeechBubble(frame: NSRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight))
            bubble.message = message
            bubbleWindow.contentView = bubble
            bubbleWindow.orderFront(nil)

            bubbleWindows.append(bubbleWindow)
        }
    }

    func hideBubbles() {
        for bubbleWindow in bubbleWindows {
            bubbleWindow.orderOut(nil)
        }
        bubbleWindows.removeAll()
    }

    func updateBubblePositions() {
        guard let mainWindow = self.window else { return }

        let bubbleWidth: CGFloat = 180
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5

        for (index, bubbleWindow) in bubbleWindows.enumerated() {
            let yOffset = CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset
            bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        closeButton.isHidden = false
        increaseButton.isHidden = false
        decreaseButton.isHidden = false
        settingsButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.isHidden = true
        increaseButton.isHidden = true
        decreaseButton.isHidden = true
        settingsButton.isHidden = true
    }
}

class ClaudeMonitor {
    var onClaudeWaiting: (([String]) -> Void)?
    var onClaudeNotWaiting: (() -> Void)?
    private var timer: Timer?
    private var lastState: Bool = false
    private var config: MaxwellConfig = MaxwellConfig.load()

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClaude()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reloadConfig() {
        config = MaxwellConfig.load()
    }

    private var lastMessages: [String] = []

    private func checkClaude() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var messages = self?.checkAllSessions() ?? []
            let remoteMessages = self?.checkRemoteSessions() ?? []
            messages.append(contentsOf: remoteMessages)
            DispatchQueue.main.async {
                if !messages.isEmpty {
                    if messages != self?.lastMessages {
                        self?.lastMessages = messages
                        self?.onClaudeWaiting?(messages)
                    }
                } else {
                    if self?.lastState != false {
                        self?.lastState = false
                        self?.lastMessages = []
                        self?.onClaudeNotWaiting?()
                    }
                }
                self?.lastState = !messages.isEmpty
            }
        }
    }

    private func checkRemoteSessions() -> [String] {
        var messages: [String] = []
        let enabledRemotes = config.remotes.filter { $0.enabled }

        for remote in enabledRemotes {
            let keyPath = NSString(string: remote.keyPath).expandingTildeInPath
            let sshCmd = "ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no -i \"\(keyPath)\" \(remote.user)@\(remote.host) 'cat /tmp/maxwell_claude/*.json 2>/dev/null'"

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", sshCmd]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    if let jsonData = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let tool = json["tool"] as? String,
                       let cwd = json["cwd"] as? String,
                       let time = json["time"] as? Int {
                        let now = Int(Date().timeIntervalSince1970)
                        if now - time > 2 && now - time < 120 {
                            let cmd = json["cmd"] as? String ?? ""
                            let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
                            let toolIcon: String
                            switch tool {
                            case "Bash": toolIcon = "🖥️"
                            case "Edit": toolIcon = "✏️"
                            case "Write": toolIcon = "📝"
                            case "Read": toolIcon = "📖"
                            default: toolIcon = "⚠️"
                            }
                            let shortCmd = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
                            let serverLabel = "[\(remote.name)] "
                            if !shortCmd.isEmpty {
                                messages.append("\(serverLabel)\(toolIcon) \(shortCmd)\n📁 \(folder)")
                            } else {
                                messages.append("\(serverLabel)\(toolIcon) \(tool)\n📁 \(folder)")
                            }
                        }
                    }
                }
            } catch {
            }
        }
        return messages
    }

    private func checkAllSessions() -> [String] {
        var messages: [String] = []

        let statusDir = "/tmp/maxwell_claude"
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: statusDir) else {
            return messages
        }

        let now = Int(Date().timeIntervalSince1970)

        fileLoop: for file in files where file.hasSuffix(".json") {
            let filePath = "\(statusDir)/\(file)"

            guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                  let fileMtime = attrs[.modificationDate] as? Date else {
                continue fileLoop
            }

            guard let data = fileManager.contents(atPath: filePath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tool = json["tool"] as? String,
                  let cwd = json["cwd"] as? String,
                  let time = json["time"] as? Int,
                  let session = json["session"] as? String else {
                continue fileLoop
            }

            let sessionHistoryPath = NSString(string: "~/.claude/projects").expandingTildeInPath
            if let sessionDirs = try? fileManager.contentsOfDirectory(atPath: sessionHistoryPath) {
                for dir in sessionDirs {
                    let transcriptPath = "\(sessionHistoryPath)/\(dir)/\(session).jsonl"
                    if let transcriptAttrs = try? fileManager.attributesOfItem(atPath: transcriptPath),
                       let transcriptMtime = transcriptAttrs[.modificationDate] as? Date {
                        if transcriptMtime.timeIntervalSince1970 > fileMtime.timeIntervalSince1970 + 2 {
                            try? fileManager.removeItem(atPath: filePath)
                            continue fileLoop
                        }
                    }
                }
            }

            if now - time > 120 {
                try? fileManager.removeItem(atPath: filePath)
                continue fileLoop
            }

            if now - time > 2 {
                let cmd = json["cmd"] as? String ?? ""
                let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
                let toolIcon: String
                switch tool {
                case "Bash": toolIcon = "🖥️"
                case "Edit": toolIcon = "✏️"
                case "Write": toolIcon = "📝"
                case "Read": toolIcon = "📖"
                default: toolIcon = "⚠️"
                }
                let shortCmd = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
                if !shortCmd.isEmpty {
                    messages.append("\(toolIcon) \(shortCmd)\n📁 \(folder)")
                } else {
                    messages.append("\(toolIcon) \(tool)\n📁 \(folder)")
                }
            }
        }

        return messages
    }

    private func checkStatusFile() -> String? {
        let statusPath = "/tmp/maxwell_claude_status.json"
        guard let data = FileManager.default.contents(atPath: statusPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool"] as? String,
              let cwd = json["cwd"] as? String,
              let time = json["time"] as? Int else {
            return nil
        }

        let cmd = json["cmd"] as? String ?? ""

        let now = Int(Date().timeIntervalSince1970)
        if now - time > 2 {
            let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
            let toolIcon: String
            switch tool {
            case "Bash": toolIcon = "🖥️"
            case "Edit": toolIcon = "✏️"
            case "Write": toolIcon = "📝"
            case "Read": toolIcon = "📖"
            default: toolIcon = "⚠️"
            }
            let shortCmd = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
            if !shortCmd.isEmpty {
                return "\(toolIcon) \(shortCmd)\n📁 \(folder)"
            }
            return "\(toolIcon) \(tool)\n📁 \(folder)"
        }
        return nil
    }

    private func checkTerminalApp() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e", "tell application \"System Events\"",
            "-e", "if not (exists process \"Terminal\") then return \"\"",
            "-e", "end tell",
            "-e", "tell application \"Terminal\"",
            "-e", "if (count of windows) is 0 then return \"\"",
            "-e", "get contents of selected tab of front window",
            "-e", "end tell"
        ]

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            let debugPath = "/tmp/maxwell_debug.txt"
            let debugContent = "ERROR: \(errorText)\n\nOUTPUT (\(text.count) chars):\n\(text.suffix(2000))"
            try? debugContent.write(toFile: debugPath, atomically: true, encoding: .utf8)

            return checkTextForClaude(text)
        } catch {
            return nil
        }
    }

    private func checkVSCode() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e", "tell application \"System Events\"",
            "-e", "if not (exists process \"Code\") then return \"NO_VSCODE\"",
            "-e", "tell process \"Code\"",
            "-e", "set frontWindow to front window",
            "-e", "set allGroups to every group of frontWindow",
            "-e", "set output to \"\"",
            "-e", "repeat with g in allGroups",
            "-e", "try",
            "-e", "set textAreas to every text area of g",
            "-e", "repeat with t in textAreas",
            "-e", "set output to output & (value of t)",
            "-e", "end repeat",
            "-e", "end try",
            "-e", "end repeat",
            "-e", "return output",
            "-e", "end tell",
            "-e", "end tell"
        ]

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            let debugPath = "/tmp/maxwell_vscode.txt"
            let debugContent = "ERROR: \(errorText)\nOUTPUT (\(text.count) chars):\n\(text.prefix(2000))"
            try? debugContent.write(toFile: debugPath, atomically: true, encoding: .utf8)

            if !text.isEmpty && text != "NO_VSCODE" && !text.contains("NO_VSCODE") {
                return checkTextForClaude(text)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func getProjectFolder() -> String? {
        let historyPath = NSString(string: "~/.claude/history.jsonl").expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: historyPath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines).reversed()
        for line in lines.prefix(10) {
            if line.contains("\"project\"") {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let project = json["project"] as? String {
                    let parts = project.components(separatedBy: "/")
                    return parts.suffix(2).joined(separator: "/")
                }
            }
        }
        return nil
    }

    private func checkTextForClaude(_ text: String) -> String? {
        let hasProceed = text.contains("Do you want to proceed?") || text.contains("Do you want to make this edit")
        let hasYes = text.contains("1. Yes")
        let hasNo = text.contains("2. No") || text.contains("3. No")

        if hasProceed && hasYes && hasNo {
            var toolType = ""
            var command = ""

            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("⏺") {
                    if line.contains("Bash(") {
                        toolType = "🖥️"
                        if let start = line.range(of: "Bash("), let end = line.range(of: ")", range: start.upperBound..<line.endIndex) {
                            command = String(line[start.upperBound..<end.lowerBound])
                        }
                    } else if line.contains("Edit(") {
                        toolType = "✏️"
                        if let start = line.range(of: "Edit("), let end = line.range(of: ")", range: start.upperBound..<line.endIndex) {
                            command = String(line[start.upperBound..<end.lowerBound])
                        }
                    } else if line.contains("Write(") {
                        toolType = "📝"
                        if let start = line.range(of: "Write("), let end = line.range(of: ")", range: start.upperBound..<line.endIndex) {
                            command = String(line[start.upperBound..<end.lowerBound])
                        }
                    } else if line.contains("Read(") {
                        toolType = "📖"
                        if let start = line.range(of: "Read("), let end = line.range(of: ")", range: start.upperBound..<line.endIndex) {
                            command = String(line[start.upperBound..<end.lowerBound])
                        }
                    }
                }
            }

            let folder = getProjectFolder() ?? ""
            let shortCommand = command.count > 15 ? String(command.prefix(15)) + "…" : command

            if !toolType.isEmpty && !command.isEmpty {
                if !folder.isEmpty {
                    return "\(toolType) \(shortCommand)\n📁 \(folder)"
                }
                return "\(toolType) \(shortCommand)"
            }
            if !folder.isEmpty {
                return "⚠️ Approve?\n📁 \(folder)"
            }
            return "⚠️ Approve?"
        }

        if text.contains("requires confirmation") || text.contains("Permission rule") {
            if text.contains("Yes") && text.contains("No") {
                return "⚠️ Approve?"
            }
        }

        return nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var containerView: HoverView!
    var claudeMonitor: ClaudeMonitor!
    var settingsController: SettingsWindowController!
    var originalY: CGFloat = 0
    var jumpTimer: Timer?
    var hasBubbles: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsController = SettingsWindowController()
        settingsController.onConfigChanged = { [weak self] in
            self?.claudeMonitor.reloadConfig()
        }

        guard let gifURL = Bundle.module.url(forResource: "Maxwell", withExtension: "gif"),
              let gifData = try? Data(contentsOf: gifURL),
              let image = NSImage(data: gifData) else {
            print("Failed to load Maxwell.gif")
            NSApplication.shared.terminate(nil)
            return
        }

        let imageSize = image.size

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true

        containerView = HoverView(frame: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        containerView.aspectRatio = imageSize.width / imageSize.height
        containerView.onSettingsClick = { [weak self] in
            self?.settingsController.show()
        }

        let imageView = DraggableImageView(frame: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.image = image
        imageView.autoresizingMask = [.width, .height]
        imageView.onDrag = { [weak self] newY in
            self?.originalY = newY
            self?.containerView.updateBubblePositions()
        }

        containerView.addSubview(imageView, positioned: .below, relativeTo: containerView.closeButton)
        window.contentView = containerView
        window.center()
        window.makeKeyAndOrderFront(nil)

        claudeMonitor = ClaudeMonitor()
        claudeMonitor.onClaudeWaiting = { [weak self] messages in
            self?.showNotifications(messages: messages)
        }
        claudeMonitor.onClaudeNotWaiting = { [weak self] in
            self?.hideNotifications()
        }
        claudeMonitor.start()
    }

    func showNotifications(messages: [String]) {
        containerView.showBubbles(messages: messages)
        startJumping()
    }

    func hideNotifications() {
        containerView.hideBubbles()
        stopJumping()
    }

    func startJumping() {
        guard !hasBubbles else { return }
        hasBubbles = true
        originalY = window.frame.origin.y
        doOneJump()
    }

    func stopJumping() {
        hasBubbles = false
        jumpTimer?.invalidate()
        jumpTimer = nil
        if originalY > 0 {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: originalY))
        }
    }

    func doOneJump() {
        guard hasBubbles else { return }

        let jumpHeight: CGFloat = 25
        let steps = 20
        let totalDuration = 0.3
        let stepDuration = totalDuration / Double(steps)
        var currentStep = 0

        jumpTimer?.invalidate()
        jumpTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self, self.hasBubbles else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let bounceProgress = sin(progress * .pi)
            let newY = self.originalY + jumpHeight * CGFloat(bounceProgress)
            self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: newY))
            self.containerView.updateBubblePositions()

            if currentStep >= steps {
                timer.invalidate()
                self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: self.originalY))
                self.containerView.updateBubblePositions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.doOneJump()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
