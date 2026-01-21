import AppKit

class DraggableImageView: NSImageView {
    var initialMouseLocation: NSPoint = .zero
    var onDrag: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDrag = true
        }
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
        onDrag?(newOrigin.y)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
    }
}

class AnimatedGIFView: NSView {
    var initialMouseLocation: NSPoint = .zero
    var onDrag: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?
    private var didDrag = false

    private var frames: [(image: CGImage, duration: Double)] = []
    private var currentFrameIndex = 0
    private var frameTimer: Timer?
    private var imageLayer: CALayer!

    var speed: Double = 1.0 {
        didSet {
            if speed != oldValue {
                restartAnimation()
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        imageLayer = CALayer()
        imageLayer.frame = bounds
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
    }

    override func layout() {
        super.layout()
        imageLayer?.frame = bounds
    }

    func loadGIF(from url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let count = CGImageSourceGetCount(source)
        frames.removeAll()

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            var frameDuration = 0.1

            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                    frameDuration = delay
                } else if let delay = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
                    frameDuration = delay
                }
            }
            frames.append((cgImage, frameDuration))
        }

        if !frames.isEmpty {
            displayFrame(0)
            startAnimation()
        }
    }

    private func displayFrame(_ index: Int) {
        guard index < frames.count else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = frames[index].image
        CATransaction.commit()
    }

    private func startAnimation() {
        guard frames.count > 1 else { return }
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        guard !frames.isEmpty else { return }
        let duration = frames[currentFrameIndex].duration / speed
        frameTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        displayFrame(currentFrameIndex)
        scheduleNextFrame()
    }

    private func restartAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
        if !frames.isEmpty {
            scheduleNextFrame()
        }
    }

    func stopAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentLocation = event.locationInWindow
        let deltaX = currentLocation.x - initialMouseLocation.x
        let deltaY = currentLocation.y - initialMouseLocation.y
        if abs(deltaX) > 3 || abs(deltaY) > 3 {
            didDrag = true
        }
        let newOrigin = NSPoint(
            x: window.frame.origin.x + deltaX,
            y: window.frame.origin.y + deltaY
        )
        window.setFrameOrigin(newOrigin)
        onDrag?(newOrigin.y)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
    }
}

class SpeechBubble: NSView {
    var message: String = "" {
        didSet { textLabel.stringValue = message }
    }

    private var visualEffectView: NSVisualEffectView?
    private var textLabel: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false

        let bubbleRect = NSRect(x: 0, y: 12, width: bounds.width, height: bounds.height - 12)

        let effect = NSVisualEffectView(frame: bubbleRect)
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        addSubview(effect)
        visualEffectView = effect

        textLabel = NSTextField(labelWithString: "")
        textLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        textLabel.textColor = NSColor.labelColor
        textLabel.alignment = .center
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 2
        textLabel.cell?.wraps = true
        textLabel.cell?.truncatesLastVisibleLine = true
        effect.addSubview(textLabel)
    }

    override func layout() {
        super.layout()
        let bubbleRect = NSRect(x: 0, y: 12, width: bounds.width, height: bounds.height - 12)
        visualEffectView?.frame = bubbleRect
        textLabel?.frame = NSRect(x: 8, y: 4, width: bubbleRect.width - 16, height: bubbleRect.height - 8)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let tailPath = NSBezierPath()
        let tailWidth: CGFloat = 12
        let centerX = bounds.width / 2
        tailPath.move(to: NSPoint(x: centerX - tailWidth / 2, y: 12))
        tailPath.line(to: NSPoint(x: centerX, y: 4))
        tailPath.line(to: NSPoint(x: centerX + tailWidth / 2, y: 12))
        tailPath.close()

        NSColor.windowBackgroundColor.withAlphaComponent(0.9).setFill()
        tailPath.fill()

        NSColor.gray.withAlphaComponent(0.3).setStroke()
        tailPath.lineWidth = 0.5
        tailPath.stroke()
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
    var gifSpeed: Double

    static let configPath = NSString(string: "~/.maxwell/config.json").expandingTildeInPath

    init(remotes: [RemoteConfig] = [], gifSpeed: Double = 1.0) {
        self.remotes = remotes
        self.gifSpeed = gifSpeed
    }

    static func load() -> MaxwellConfig {
        guard let data = FileManager.default.contents(atPath: configPath),
              let config = try? JSONDecoder().decode(MaxwellConfig.self, from: data) else {
            return MaxwellConfig()
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
    var speedSlider: NSSlider!
    var speedLabel: NSTextField!

    private var sidebarTableView: NSTableView!
    private var contentContainerView: NSView!
    private var sshContentView: NSView!
    private var othersContentView: NSView!
    private let menuItems = ["SSH", "Others"]

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
        updateSpeedUI()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Maxwell Settings"
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 400))

        let sidebarWidth: CGFloat = 120
        let sidebarView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: sidebarWidth, height: 400))
        sidebarView.material = .sidebar
        sidebarView.blendingMode = .behindWindow
        contentView.addSubview(sidebarView)

        let sidebarScrollView = NSScrollView(frame: NSRect(x: 0, y: 50, width: sidebarWidth, height: 350))
        sidebarScrollView.drawsBackground = false
        sidebarTableView = NSTableView(frame: sidebarScrollView.bounds)
        sidebarTableView.dataSource = self
        sidebarTableView.delegate = self
        sidebarTableView.rowHeight = 32
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.headerView = nil
        sidebarTableView.style = .sourceList

        let sidebarCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebar"))
        sidebarCol.width = sidebarWidth - 4
        sidebarTableView.addTableColumn(sidebarCol)

        sidebarScrollView.documentView = sidebarTableView
        sidebarScrollView.hasVerticalScroller = false
        sidebarView.addSubview(sidebarScrollView)

        contentContainerView = NSView(frame: NSRect(x: sidebarWidth, y: 0, width: 550 - sidebarWidth, height: 400))
        contentView.addSubview(contentContainerView)

        setupSSHContent()
        setupOthersContent()

        sshContentView.isHidden = false
        othersContentView.isHidden = true

        let saveButton = NSButton(frame: NSRect(x: 550 - 110, y: 10, width: 100, height: 30))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        contentView.addSubview(saveButton)

        w.contentView = contentView
        window = w

        sidebarTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    private func setupSSHContent() {
        sshContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(sshContentView)

        let label = NSTextField(labelWithString: "Remote SSH Servers")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 355, width: 200, height: 20)
        sshContentView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 100, width: 390, height: 245))
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 24

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 70
        tableView.addTableColumn(nameCol)

        let hostCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("host"))
        hostCol.title = "Host"
        hostCol.width = 100
        tableView.addTableColumn(hostCol)

        let userCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("user"))
        userCol.title = "User"
        userCol.width = 70
        tableView.addTableColumn(userCol)

        let keyCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("keyPath"))
        keyCol.title = "SSH Key Path"
        keyCol.width = 110
        tableView.addTableColumn(keyCol)

        let enabledCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledCol.title = "On"
        enabledCol.width = 30
        tableView.addTableColumn(enabledCol)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        sshContentView.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 20, y: 60, width: 80, height: 30))
        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addRemote)
        sshContentView.addSubview(addButton)

        let removeButton = NSButton(frame: NSRect(x: 110, y: 60, width: 80, height: 30))
        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeRemote)
        sshContentView.addSubview(removeButton)
    }

    private func setupOthersContent() {
        othersContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(othersContentView)

        let label = NSTextField(labelWithString: "Animation")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 355, width: 200, height: 20)
        othersContentView.addSubview(label)

        let speedTitleLabel = NSTextField(labelWithString: "GIF Speed:")
        speedTitleLabel.font = NSFont.systemFont(ofSize: 13)
        speedTitleLabel.frame = NSRect(x: 20, y: 310, width: 80, height: 20)
        othersContentView.addSubview(speedTitleLabel)

        speedSlider = NSSlider(frame: NSRect(x: 100, y: 310, width: 200, height: 20))
        speedSlider.minValue = 0.25
        speedSlider.maxValue = 3.0
        speedSlider.doubleValue = config.gifSpeed
        speedSlider.target = self
        speedSlider.action = #selector(speedSliderChanged(_:))
        othersContentView.addSubview(speedSlider)

        speedLabel = NSTextField(labelWithString: formatSpeed(config.gifSpeed))
        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        speedLabel.frame = NSRect(x: 310, y: 310, width: 60, height: 20)
        othersContentView.addSubview(speedLabel)

        let slowLabel = NSTextField(labelWithString: "Slow")
        slowLabel.font = NSFont.systemFont(ofSize: 10)
        slowLabel.textColor = .secondaryLabelColor
        slowLabel.frame = NSRect(x: 100, y: 290, width: 40, height: 14)
        othersContentView.addSubview(slowLabel)

        let fastLabel = NSTextField(labelWithString: "Fast")
        fastLabel.font = NSFont.systemFont(ofSize: 10)
        fastLabel.textColor = .secondaryLabelColor
        fastLabel.frame = NSRect(x: 270, y: 290, width: 30, height: 14)
        othersContentView.addSubview(fastLabel)

        let resetButton = NSButton(frame: NSRect(x: 20, y: 250, width: 100, height: 24))
        resetButton.title = "Reset to 1x"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetSpeed)
        othersContentView.addSubview(resetButton)
    }

    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2fx", speed)
    }

    private func updateSpeedUI() {
        speedSlider?.doubleValue = config.gifSpeed
        speedLabel?.stringValue = formatSpeed(config.gifSpeed)
    }

    @objc private func speedSliderChanged(_ sender: NSSlider) {
        config.gifSpeed = sender.doubleValue
        speedLabel.stringValue = formatSpeed(config.gifSpeed)
    }

    @objc private func resetSpeed() {
        config.gifSpeed = 1.0
        updateSpeedUI()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == sidebarTableView {
            return menuItems.count
        }
        return config.remotes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == sidebarTableView {
            let cellId = NSUserInterfaceItemIdentifier("SidebarCell")
            var cell = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView
            if cell == nil {
                cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: 116, height: 32))
                cell?.identifier = cellId
                let textField = NSTextField(labelWithString: "")
                textField.frame = NSRect(x: 8, y: 6, width: 100, height: 20)
                textField.font = NSFont.systemFont(ofSize: 13)
                cell?.addSubview(textField)
                cell?.textField = textField
            }
            cell?.textField?.stringValue = menuItems[row]
            return cell
        }

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

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView, tableView == sidebarTableView else { return }
        let selectedRow = tableView.selectedRow
        sshContentView.isHidden = selectedRow != 0
        othersContentView.isHidden = selectedRow != 1
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
    var finishedBubbleWindows: [NSWindow] = []
    var onSettingsClick: (() -> Void)?
    var onResize: (() -> Void)?
    var onFinishedBubbleClick: (() -> Void)?

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
        onResize?()
    }

    func showBubbles(messages: [String]) {
        hideBubbles()

        guard let mainWindow = self.window else { return }

        let maxBubbleWidth = mainWindow.frame.width
        let minBubbleWidth: CGFloat = 120
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5
        let padding: CGFloat = 24

        for (index, message) in messages.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: .medium)
            let lines = message.components(separatedBy: "\n")
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let size = (line as NSString).size(withAttributes: attrs)
                maxLineWidth = max(maxLineWidth, size.width)
            }
            let bubbleWidth = min(max(maxLineWidth + padding, minBubbleWidth), maxBubbleWidth)

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

    func showFinishedBubbles(messages: [String]) {
        hideFinishedBubbles()

        guard let mainWindow = self.window else { return }

        let maxBubbleWidth = mainWindow.frame.width
        let minBubbleWidth: CGFloat = 120
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5
        let padding: CGFloat = 24

        let baseYOffset = CGFloat(bubbleWindows.count) * (bubbleHeight + spacing)

        for (index, message) in messages.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: .medium)
            let lines = message.components(separatedBy: "\n")
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let size = (line as NSString).size(withAttributes: attrs)
                maxLineWidth = max(maxLineWidth, size.width)
            }
            let bubbleWidth = min(max(maxLineWidth + padding, minBubbleWidth), maxBubbleWidth)

            let yOffset = baseYOffset + CGFloat(index) * (bubbleHeight + spacing)
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

            finishedBubbleWindows.append(bubbleWindow)
        }
    }

    func hideFinishedBubbles() {
        for bubbleWindow in finishedBubbleWindows {
            bubbleWindow.orderOut(nil)
        }
        finishedBubbleWindows.removeAll()
    }

    func updateBubblePositions() {
        guard let mainWindow = self.window else { return }

        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5

        for (index, bubbleWindow) in bubbleWindows.enumerated() {
            let bubbleWidth = bubbleWindow.frame.width
            let yOffset = CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset
            bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        }

        let baseYOffset = CGFloat(bubbleWindows.count) * (bubbleHeight + spacing)
        for (index, bubbleWindow) in finishedBubbleWindows.enumerated() {
            let bubbleWidth = bubbleWindow.frame.width
            let yOffset = baseYOffset + CGFloat(index) * (bubbleHeight + spacing)
            let bubbleX = mainWindow.frame.midX - bubbleWidth / 2
            let bubbleY = mainWindow.frame.maxY + 5 + yOffset
            bubbleWindow.setFrameOrigin(NSPoint(x: bubbleX, y: bubbleY))
        }
    }

    func showMeow() {
        let meowLabel = NSTextField(labelWithString: "meow")
        meowLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        meowLabel.textColor = NSColor.labelColor
        meowLabel.backgroundColor = .clear
        meowLabel.isBezeled = false
        meowLabel.isEditable = false
        meowLabel.sizeToFit()

        let padding: CGFloat = 30
        let maxX = bounds.width - meowLabel.frame.width - padding
        let maxY = bounds.height - meowLabel.frame.height - padding
        let randomX = CGFloat.random(in: padding...max(padding, maxX))
        let randomY = CGFloat.random(in: padding...max(padding, maxY))
        meowLabel.frame.origin = NSPoint(x: randomX, y: randomY)
        meowLabel.alphaValue = 1.0
        addSubview(meowLabel)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 1.0
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            meowLabel.animator().frame.origin.y += 40
            meowLabel.animator().alphaValue = 0
        }, completionHandler: {
            meowLabel.removeFromSuperview()
        })
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
    var onClaudeFinished: (([String]) -> Void)?
    var onClaudeFinishedCleared: (() -> Void)?
    private var timer: Timer?
    private var lastState: Bool = false
    private var config: MaxwellConfig = MaxwellConfig.load()
    private var dismissedSessions: Set<String> = []

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

    func dismissFinishedSessions() {
        dismissedSessions = dismissedSessions.union(lastFinishedSessions)
        lastFinishedMessages = []
        onClaudeFinishedCleared?()
    }

    private var lastMessages: [String] = []
    private var lastFinishedMessages: [String] = []
    private var lastFinishedSessions: Set<String> = []

    private func checkClaude() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var messages = self?.checkAllSessions() ?? []
            let remoteMessages = self?.checkRemoteSessions() ?? []
            messages.append(contentsOf: remoteMessages)

            let (finishedMessages, finishedSessions) = self?.checkFinishedSessions() ?? ([], [])

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

                if !finishedMessages.isEmpty {
                    if finishedMessages != self?.lastFinishedMessages {
                        self?.lastFinishedMessages = finishedMessages
                        self?.lastFinishedSessions = finishedSessions
                        self?.onClaudeFinished?(finishedMessages)
                    }
                } else if !(self?.lastFinishedMessages.isEmpty ?? true) {
                    self?.lastFinishedMessages = []
                    self?.lastFinishedSessions = []
                    self?.dismissedSessions = []
                    self?.onClaudeFinishedCleared?()
                }
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

    private func cleanupStoppedMarkers() {
        let stoppedDir = "/tmp/maxwell_claude_stopped"
        let fileManager = FileManager.default
        let now = Int(Date().timeIntervalSince1970)

        guard let files = try? fileManager.contentsOfDirectory(atPath: stoppedDir) else {
            return
        }

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(stoppedDir)/\(file)"
            if let data = fileManager.contents(atPath: filePath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let time = json["time"] as? Int {
                if now - time > 300 {
                    try? fileManager.removeItem(atPath: filePath)
                }
            }
        }
    }

    private func checkFinishedSessions() -> ([String], Set<String>) {
        var messages: [String] = []
        var sessionIds: Set<String> = []
        let fileManager = FileManager.default
        let projectsPath = NSString(string: "~/.claude/projects").expandingTildeInPath
        let statusDir = "/tmp/maxwell_claude"
        let stoppedDir = "/tmp/maxwell_claude_stopped"

        cleanupStoppedMarkers()

        guard let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) else {
            return (messages, sessionIds)
        }

        let now = Date()
        let maxAge: TimeInterval = 300

        for projectDir in projectDirs {
            let projectPath = "\(projectsPath)/\(projectDir)"
            guard let files = try? fileManager.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = "\(projectPath)/\(file)"
                let sessionId = String(file.dropLast(6))

                if dismissedSessions.contains(sessionId) {
                    continue
                }

                let wasStopped = fileManager.fileExists(atPath: "\(stoppedDir)/\(sessionId).json")
                if wasStopped {
                    continue
                }

                guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                      let mtime = attrs[.modificationDate] as? Date else {
                    continue
                }

                let age = now.timeIntervalSince(mtime)
                if age < 5 || age > maxAge {
                    continue
                }

                let hasActiveStatus = fileManager.fileExists(atPath: "\(statusDir)/\(sessionId).json")
                if hasActiveStatus {
                    continue
                }

                guard let data = fileManager.contents(atPath: filePath),
                      let content = String(data: data, encoding: .utf8) else {
                    continue
                }

                let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

                var lastRelevantType: String? = nil
                var userMessageCount = 0
                var assistantMessageCount = 0
                var lastUserPrompt: String? = nil

                for line in lines.reversed() {
                    guard let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          let msgType = json["type"] as? String else {
                        continue
                    }
                    if msgType == "assistant" {
                        assistantMessageCount += 1
                        if lastRelevantType == nil {
                            lastRelevantType = msgType
                        }
                    } else if msgType == "user" {
                        userMessageCount += 1
                        if lastRelevantType == nil {
                            lastRelevantType = msgType
                        }
                        if lastUserPrompt == nil {
                            if let message = json["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                lastUserPrompt = content
                            }
                        }
                    }
                    if userMessageCount >= 2 && assistantMessageCount >= 2 && lastUserPrompt != nil {
                        break
                    }
                }

                if lastRelevantType == "assistant" && userMessageCount >= 1 && assistantMessageCount >= 1 {
                    if !sessionIds.contains(sessionId) {
                        let folderParts = projectDir.split(separator: "-").suffix(2)
                        let folder = folderParts.joined(separator: "/")
                        let prompt = lastUserPrompt ?? ""
                        let shortPrompt = prompt.count > 30 ? String(prompt.prefix(30)) + "…" : prompt
                        messages.append("✅ \(shortPrompt)\n📁 \(folder)")
                        sessionIds.insert(sessionId)
                    }
                }
            }
        }

        return (messages, sessionIds)
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
    var gifView: AnimatedGIFView!
    var originalY: CGFloat = 0
    var jumpTimer: Timer?
    var hasBubbles: Bool = false
    var hasFinishedBubbles: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = MaxwellConfig.load()

        settingsController = SettingsWindowController()
        settingsController.onConfigChanged = { [weak self] in
            self?.claudeMonitor.reloadConfig()
            self?.applyGifSpeed()
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
        containerView.onResize = { [weak self] in
            self?.saveWindowFrame()
        }

        gifView = AnimatedGIFView(frame: NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        gifView.autoresizingMask = [.width, .height]
        gifView.speed = config.gifSpeed
        gifView.loadGIF(from: gifURL)
        gifView.onDrag = { [weak self] newY in
            self?.originalY = newY
            self?.containerView.updateBubblePositions()
            self?.saveWindowFrame()
        }
        gifView.onClick = { [weak self] in
            if self?.hasFinishedBubbles == true {
                self?.dismissFinishedNotifications()
            } else {
                self?.doClickJump()
                self?.containerView.showMeow()
            }
        }

        containerView.addSubview(gifView, positioned: .below, relativeTo: containerView.closeButton)
        window.contentView = containerView
        restoreWindowFrame()
        window.makeKeyAndOrderFront(nil)

        claudeMonitor = ClaudeMonitor()
        claudeMonitor.onClaudeWaiting = { [weak self] messages in
            self?.showNotifications(messages: messages)
        }
        claudeMonitor.onClaudeNotWaiting = { [weak self] in
            self?.hideNotifications()
        }
        claudeMonitor.onClaudeFinished = { [weak self] messages in
            self?.showFinishedNotifications(messages: messages)
        }
        claudeMonitor.onClaudeFinishedCleared = { [weak self] in
            self?.hideFinishedNotifications()
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

    func showFinishedNotifications(messages: [String]) {
        containerView.showFinishedBubbles(messages: messages)
        hasFinishedBubbles = true
    }

    func hideFinishedNotifications() {
        containerView.hideFinishedBubbles()
        hasFinishedBubbles = false
    }

    func dismissFinishedNotifications() {
        claudeMonitor.dismissFinishedSessions()
        hideFinishedNotifications()
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

        let jumpHeight: CGFloat = 35
        let steps = 20
        let totalDuration = 0.4
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
                self.doOneJump()
            }
        }
    }

    func doClickJump() {
        guard !hasBubbles else { return }

        let startY = window.frame.origin.y
        let jumpHeight: CGFloat = 20
        let steps = 16
        let totalDuration = 0.25
        let stepDuration = totalDuration / Double(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let bounceProgress = sin(progress * .pi)
            let newY = startY + jumpHeight * CGFloat(bounceProgress)
            self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: newY))

            if currentStep >= steps {
                timer.invalidate()
                self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: startY))
            }
        }
    }

    private func applyGifSpeed() {
        let config = MaxwellConfig.load()
        gifView.speed = config.gifSpeed
    }

    private func saveWindowFrame() {
        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: "maxwell_x")
        UserDefaults.standard.set(frame.origin.y, forKey: "maxwell_y")
        UserDefaults.standard.set(frame.width, forKey: "maxwell_width")
        UserDefaults.standard.set(frame.height, forKey: "maxwell_height")
        UserDefaults.standard.synchronize()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowFrame()
    }

    private func restoreWindowFrame() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "maxwell_x") != nil {
            let x = defaults.double(forKey: "maxwell_x")
            let y = defaults.double(forKey: "maxwell_y")
            let width = defaults.double(forKey: "maxwell_width")
            let height = defaults.double(forKey: "maxwell_height")
            if width > 0 && height > 0 {
                window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
                return
            }
        }
        window.center()
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
