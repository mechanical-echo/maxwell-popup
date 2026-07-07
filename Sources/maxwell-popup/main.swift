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

    var draggable: Bool = true

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
        stopAnimation()
        currentFrameIndex = 0
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
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
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
        guard draggable, let window = self.window else { return }
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
    var isClickable: Bool = false {
        didSet { updateClickableAppearance() }
    }
    var onTap: (() -> Void)?

    private var visualEffectView: NSVisualEffectView?
    private var textLabel: NSTextField!
    private var arrowLabel: NSTextField?
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
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

        let arrow = NSTextField(labelWithString: "›")
        arrow.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        arrow.textColor = NSColor.secondaryLabelColor
        arrow.alignment = .center
        arrow.isHidden = true
        effect.addSubview(arrow)
        arrowLabel = arrow
    }

    private func updateClickableAppearance() {
        arrowLabel?.isHidden = !isClickable
        if isClickable {
            textLabel?.frame = NSRect(x: 8, y: 4, width: (visualEffectView?.bounds.width ?? bounds.width) - 28, height: (visualEffectView?.bounds.height ?? bounds.height - 12) - 8)
        } else {
            textLabel?.frame = NSRect(x: 8, y: 4, width: (visualEffectView?.bounds.width ?? bounds.width) - 16, height: (visualEffectView?.bounds.height ?? bounds.height - 12) - 8)
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
        if isClickable {
            NSCursor.pointingHand.set()
            visualEffectView?.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            visualEffectView?.layer?.borderWidth = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        visualEffectView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        visualEffectView?.layer?.borderWidth = 0.5
    }

    override func mouseDown(with event: NSEvent) {
        if isClickable {
            onTap?()
        }
    }

    override func layout() {
        super.layout()
        let bubbleRect = NSRect(x: 0, y: 12, width: bounds.width, height: bounds.height - 12)
        visualEffectView?.frame = bubbleRect
        let textWidth = isClickable ? bubbleRect.width - 28 : bubbleRect.width - 16
        textLabel?.frame = NSRect(x: 8, y: 4, width: textWidth, height: bubbleRect.height - 8)
        arrowLabel?.frame = NSRect(x: bubbleRect.width - 20, y: 8, width: 16, height: bubbleRect.height - 16)
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

struct SessionInfo {
    var message: String
    var cwd: String
    var sessionId: String
    var isRemote: Bool
    var remoteName: String?
    var tmuxSession: String?
}

struct MaxwellConfig: Codable {
    var remotes: [RemoteConfig]
    var gifSpeed: Double
    var showDoneBubbles: Bool
    var telegramEnabled: Bool
    var theme: String
    var clickMessage: String

    static let configPath = NSString(string: "~/.maxwell/config.json").expandingTildeInPath
    static let telegramToken = "***REMOVED***"
    static let telegramChatId = "***REMOVED***"
    static let defaultTheme = "Maxwell.gif"
    static let defaultClickMessage = "meow"

    init(remotes: [RemoteConfig] = [], gifSpeed: Double = 1.0, showDoneBubbles: Bool = false,
         telegramEnabled: Bool = false, theme: String = MaxwellConfig.defaultTheme,
         clickMessage: String = MaxwellConfig.defaultClickMessage) {
        self.remotes = remotes
        self.gifSpeed = gifSpeed
        self.showDoneBubbles = showDoneBubbles
        self.telegramEnabled = telegramEnabled
        self.theme = theme
        self.clickMessage = clickMessage
    }

    enum CodingKeys: String, CodingKey {
        case remotes, gifSpeed, showDoneBubbles, telegramEnabled, theme, clickMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remotes = (try? c.decode([RemoteConfig].self, forKey: .remotes)) ?? []
        gifSpeed = (try? c.decode(Double.self, forKey: .gifSpeed)) ?? 1.0
        showDoneBubbles = (try? c.decode(Bool.self, forKey: .showDoneBubbles)) ?? false
        telegramEnabled = (try? c.decode(Bool.self, forKey: .telegramEnabled)) ?? false
        theme = (try? c.decode(String.self, forKey: .theme)) ?? MaxwellConfig.defaultTheme
        clickMessage = (try? c.decode(String.self, forKey: .clickMessage)) ?? MaxwellConfig.defaultClickMessage
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

enum ThemeManager {
    static let gifsDirectory = NSString(string: "~/.maxwell/gifs").expandingTildeInPath
    static let bundledGifs = ["Maxwell", "Maxwell_pixel"]

    static func seedIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: gifsDirectory, withIntermediateDirectories: true)
        for name in bundledGifs {
            let dest = (gifsDirectory as NSString).appendingPathComponent("\(name).gif")
            guard !fm.fileExists(atPath: dest),
                  let src = Bundle.module.url(forResource: name, withExtension: "gif") else { continue }
            try? fm.copyItem(at: src, to: URL(fileURLWithPath: dest))
        }
    }

    static func availableThemes() -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: gifsDirectory),
            includingPropertiesForKeys: nil) else { return [] }
        return items
            .filter { $0.pathExtension.lowercased() == "gif" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func gifURL(for theme: String) -> URL? {
        let path = (gifsDirectory as NSString).appendingPathComponent(theme)
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let base = (theme as NSString).deletingPathExtension
        return Bundle.module.url(forResource: base.isEmpty ? "Maxwell" : base, withExtension: "gif")
            ?? Bundle.module.url(forResource: "Maxwell", withExtension: "gif")
    }

    static func displayName(for url: URL) -> String {
        return (url.lastPathComponent as NSString).deletingPathExtension
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class ThemeTileView: NSView {
    let themeFileName: String
    var onSelect: (() -> Void)?
    var isSelected: Bool { didSet { needsDisplay = true } }
    private let previewView: AnimatedGIFView

    init(frame frameRect: NSRect, url: URL, isSelected: Bool) {
        self.themeFileName = url.lastPathComponent
        self.isSelected = isSelected
        self.previewView = AnimatedGIFView(
            frame: NSRect(x: 8, y: 24, width: frameRect.width - 16, height: frameRect.height - 32))
        super.init(frame: frameRect)
        wantsLayer = true

        previewView.draggable = false
        previewView.speed = 1.0
        previewView.onClick = { [weak self] in self?.onSelect?() }
        addSubview(previewView)
        previewView.loadGIF(from: url)

        let nameLabel = NSTextField(labelWithString: ThemeManager.displayName(for: url))
        nameLabel.font = NSFont.systemFont(ofSize: 11)
        nameLabel.alignment = .center
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 2, y: 4, width: frameRect.width - 4, height: 16)
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        if isSelected {
            NSColor(calibratedRed: 1.0, green: 182 / 255, blue: 193 / 255, alpha: 0.22).setFill()
            path.fill()
            NSColor(calibratedRed: 1.0, green: 140 / 255, blue: 170 / 255, alpha: 1.0).setStroke()
            path.lineWidth = 3
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }
}

struct PendingTelegramAction {
    var session: SessionInfo
    var remoteConfig: RemoteConfig?
    var messageId: Int?
}

class TelegramNotifier {
    private var lastNotifiedMessages: Set<String> = []
    private var lastNotificationTime: Date = .distantPast
    private let minInterval: TimeInterval = 5
    private var pendingActions: [String: PendingTelegramAction] = [:]
    private var pollTimer: Timer?
    private var lastUpdateId: Int = 0

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollUpdates()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func sendWaitingNotification(sessions: [SessionInfo], remotes: [RemoteConfig]) {
        let config = MaxwellConfig.load()
        guard config.telegramEnabled else { return }

        let now = Date()
        guard now.timeIntervalSince(lastNotificationTime) >= minInterval else { return }

        let currentMessages = Set(sessions.map { $0.message })
        let newMessages = currentMessages.subtracting(lastNotifiedMessages)
        guard !newMessages.isEmpty else { return }

        lastNotifiedMessages = currentMessages
        lastNotificationTime = now

        for session in sessions where newMessages.contains(session.message) {
            let remoteConfig = remotes.first { $0.name == session.remoteName }
            let canAccept = session.isRemote && session.tmuxSession != nil && !session.tmuxSession!.isEmpty && remoteConfig != nil
            send(session: session, remoteConfig: remoteConfig, canAccept: canAccept)
        }
    }

    func clearNotifiedMessages() {
        lastNotifiedMessages.removeAll()
        pendingActions.removeAll()
    }

    private func send(session: SessionInfo, remoteConfig: RemoteConfig?, canAccept: Bool) {
        let urlString = "https://api.telegram.org/bot\(MaxwellConfig.telegramToken)/sendMessage"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let text = "⚠️ Claude waiting\n\n\(session.message)"
        let callbackId = UUID().uuidString.prefix(8).lowercased()

        var body: [String: Any] = [
            "chat_id": MaxwellConfig.telegramChatId,
            "text": text
        ]

        if canAccept {
            let keyboard: [String: Any] = [
                "inline_keyboard": [[
                    ["text": "✅ Accept", "callback_data": "accept_\(callbackId)"],
                    ["text": "❌ Reject", "callback_data": "reject_\(callbackId)"]
                ]]
            ]
            body["reply_markup"] = keyboard

            pendingActions[String(callbackId)] = PendingTelegramAction(
                session: session,
                remoteConfig: remoteConfig,
                messageId: nil
            )
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            if canAccept, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let messageId = result["message_id"] as? Int {
                DispatchQueue.main.async {
                    if var pending = self?.pendingActions[String(callbackId)] {
                        pending.messageId = messageId
                        self?.pendingActions[String(callbackId)] = pending
                    }
                }
            }
        }.resume()
    }

    private func pollUpdates() {
        let config = MaxwellConfig.load()
        guard config.telegramEnabled else { return }

        let urlString = "https://api.telegram.org/bot\(MaxwellConfig.telegramToken)/getUpdates?offset=\(lastUpdateId + 1)&timeout=1"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["result"] as? [[String: Any]] else { return }

            for update in results {
                if let updateId = update["update_id"] as? Int {
                    self?.lastUpdateId = max(self?.lastUpdateId ?? 0, updateId)
                }

                if let callbackQuery = update["callback_query"] as? [String: Any],
                   let data = callbackQuery["data"] as? String,
                   let callbackId = callbackQuery["id"] as? String {
                    self?.handleCallback(data: data, callbackQueryId: callbackId)
                }
            }
        }.resume()
    }

    private func handleCallback(data: String, callbackQueryId: String) {
        let parts = data.split(separator: "_")
        guard parts.count == 2 else { return }

        let action = String(parts[0])
        let id = String(parts[1])

        guard let pending = pendingActions[id] else {
            answerCallback(callbackQueryId: callbackQueryId, text: "Session expired")
            return
        }

        if action == "accept" {
            executeAccept(pending: pending) { [weak self] success in
                DispatchQueue.main.async {
                    self?.answerCallback(callbackQueryId: callbackQueryId, text: success ? "✅ Accepted!" : "❌ Failed")
                    if success, let messageId = pending.messageId {
                        self?.updateMessage(messageId: messageId, text: "✅ Accepted\n\n\(pending.session.message)")
                    }
                    self?.pendingActions.removeValue(forKey: id)
                }
            }
        } else if action == "reject" {
            executeReject(pending: pending) { [weak self] success in
                DispatchQueue.main.async {
                    self?.answerCallback(callbackQueryId: callbackQueryId, text: success ? "❌ Rejected" : "❌ Failed")
                    if success, let messageId = pending.messageId {
                        self?.updateMessage(messageId: messageId, text: "❌ Rejected\n\n\(pending.session.message)")
                    }
                    self?.pendingActions.removeValue(forKey: id)
                }
            }
        }
    }

    private func executeAccept(pending: PendingTelegramAction, completion: @escaping (Bool) -> Void) {
        guard let remote = pending.remoteConfig,
              let tmuxSession = pending.session.tmuxSession else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let keyPath = NSString(string: remote.keyPath).expandingTildeInPath
            let sshCmd = "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i \"\(keyPath)\" \(remote.user)@\(remote.host) \"tmux send-keys -t '\(tmuxSession)' '1' Enter\""

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", sshCmd]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                completion(task.terminationStatus == 0)
            } catch {
                completion(false)
            }
        }
    }

    private func executeReject(pending: PendingTelegramAction, completion: @escaping (Bool) -> Void) {
        guard let remote = pending.remoteConfig,
              let tmuxSession = pending.session.tmuxSession else {
            completion(false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let keyPath = NSString(string: remote.keyPath).expandingTildeInPath
            let sshCmd = "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i \"\(keyPath)\" \(remote.user)@\(remote.host) \"tmux send-keys -t '\(tmuxSession)' '2' Enter\""

            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", sshCmd]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                completion(task.terminationStatus == 0)
            } catch {
                completion(false)
            }
        }
    }

    private func answerCallback(callbackQueryId: String, text: String) {
        let urlString = "https://api.telegram.org/bot\(MaxwellConfig.telegramToken)/answerCallbackQuery"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "callback_query_id": callbackQueryId,
            "text": text
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request).resume()
    }

    private func updateMessage(messageId: Int, text: String) {
        let urlString = "https://api.telegram.org/bot\(MaxwellConfig.telegramToken)/editMessageText"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "chat_id": MaxwellConfig.telegramChatId,
            "message_id": messageId,
            "text": text
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request).resume()
    }
}

class SettingsWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var window: NSWindow?
    var tableView: NSTableView!
    var config: MaxwellConfig
    var onConfigChanged: (() -> Void)?
    var speedSlider: NSSlider!
    var speedLabel: NSTextField!
    var showDoneBubblesCheckbox: NSButton!
    var telegramEnabledCheckbox: NSButton!

    private var sidebarTableView: NSTableView!
    private var contentContainerView: NSView!
    private var sshContentView: NSView!
    private var othersContentView: NSView!
    private var themeContentView: NSView!
    private var themeGridDocView: FlippedView!
    private var messageField: NSTextField!
    private var themeTiles: [ThemeTileView] = []
    private let menuItems = ["SSH", "Others", "Theme"]

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
        updateDoneBubblesUI()
        updateTelegramUI()
        messageField?.stringValue = config.clickMessage
        populateThemeGrid()
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
        setupThemeContent()

        sshContentView.isHidden = false
        othersContentView.isHidden = true
        themeContentView.isHidden = true

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

        let testButton = NSButton(frame: NSRect(x: 200, y: 60, width: 80, height: 30))
        testButton.title = "Test"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testSSH)
        sshContentView.addSubview(testButton)
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

        let notificationsLabel = NSTextField(labelWithString: "Notifications")
        notificationsLabel.font = NSFont.boldSystemFont(ofSize: 14)
        notificationsLabel.frame = NSRect(x: 20, y: 200, width: 200, height: 20)
        othersContentView.addSubview(notificationsLabel)

        showDoneBubblesCheckbox = NSButton(checkboxWithTitle: "Show done bubbles", target: self, action: #selector(doneBubblesChanged(_:)))
        showDoneBubblesCheckbox.frame = NSRect(x: 20, y: 170, width: 200, height: 20)
        showDoneBubblesCheckbox.state = config.showDoneBubbles ? .on : .off
        othersContentView.addSubview(showDoneBubblesCheckbox)

        telegramEnabledCheckbox = NSButton(checkboxWithTitle: "Telegram notifications", target: self, action: #selector(telegramEnabledChanged(_:)))
        telegramEnabledCheckbox.frame = NSRect(x: 20, y: 145, width: 200, height: 20)
        telegramEnabledCheckbox.state = config.telegramEnabled ? .on : .off
        othersContentView.addSubview(telegramEnabledCheckbox)
    }

    private func setupThemeContent() {
        themeContentView = NSView(frame: contentContainerView.bounds)
        contentContainerView.addSubview(themeContentView)

        let title = NSTextField(labelWithString: "Theme")
        title.font = NSFont.boldSystemFont(ofSize: 14)
        title.frame = NSRect(x: 20, y: 370, width: 200, height: 20)
        themeContentView.addSubview(title)

        let msgLabel = NSTextField(labelWithString: "Message on click:")
        msgLabel.font = NSFont.systemFont(ofSize: 13)
        msgLabel.frame = NSRect(x: 20, y: 338, width: 130, height: 20)
        themeContentView.addSubview(msgLabel)

        messageField = NSTextField(frame: NSRect(x: 150, y: 335, width: 240, height: 24))
        messageField.stringValue = config.clickMessage
        messageField.placeholderString = MaxwellConfig.defaultClickMessage
        messageField.identifier = NSUserInterfaceItemIdentifier("clickMessage")
        messageField.delegate = self
        themeContentView.addSubview(messageField)

        let hint = NSTextField(labelWithString: "Drop .gif files into ~/.maxwell/gifs to add more themes")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 312, width: 390, height: 14)
        themeContentView.addSubview(hint)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 15, width: 390, height: 290))
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        themeGridDocView = FlippedView(frame: NSRect(x: 0, y: 0, width: 372, height: 290))
        scrollView.documentView = themeGridDocView
        themeContentView.addSubview(scrollView)

        populateThemeGrid()
    }

    private func populateThemeGrid() {
        guard themeGridDocView != nil else { return }
        themeTiles.forEach { $0.removeFromSuperview() }
        themeTiles.removeAll()

        let themes = ThemeManager.availableThemes()
        let columns = 3
        let tileW: CGFloat = 116
        let tileH: CGFloat = 96
        let hGap: CGFloat = 6
        let vGap: CGFloat = 10
        let rows = (themes.count + columns - 1) / columns
        let docHeight = max(290, CGFloat(rows) * (tileH + vGap) + vGap)
        themeGridDocView.frame = NSRect(x: 0, y: 0, width: 372, height: docHeight)

        for (index, url) in themes.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = hGap + CGFloat(col) * (tileW + hGap)
            let y = vGap + CGFloat(row) * (tileH + vGap)
            let tile = ThemeTileView(
                frame: NSRect(x: x, y: y, width: tileW, height: tileH),
                url: url,
                isSelected: url.lastPathComponent == config.theme)
            tile.onSelect = { [weak self] in self?.selectTheme(tile.themeFileName) }
            themeGridDocView.addSubview(tile)
            themeTiles.append(tile)
        }
    }

    private func selectTheme(_ fileName: String) {
        config.theme = fileName
        for tile in themeTiles {
            tile.isSelected = tile.themeFileName == fileName
        }
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

    private func updateDoneBubblesUI() {
        showDoneBubblesCheckbox?.state = config.showDoneBubbles ? .on : .off
    }

    private func updateTelegramUI() {
        telegramEnabledCheckbox?.state = config.telegramEnabled ? .on : .off
    }

    @objc private func doneBubblesChanged(_ sender: NSButton) {
        config.showDoneBubbles = sender.state == .on
    }

    @objc private func telegramEnabledChanged(_ sender: NSButton) {
        config.telegramEnabled = sender.state == .on
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
        themeContentView.isHidden = selectedRow != 2
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

    @objc private func testSSH() {
        let row = tableView.selectedRow
        guard row >= 0 && row < config.remotes.count else {
            showAlert(title: "No Selection", message: "Please select a remote to test.")
            return
        }

        let remote = config.remotes[row]
        let keyPath = NSString(string: remote.keyPath).expandingTildeInPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            task.arguments = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=no",
                "-i", keyPath,
                "\(remote.user)@\(remote.host)",
                "echo ok"
            ]

            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe

            do {
                try task.run()
                task.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if task.terminationStatus == 0 && output.contains("ok") {
                        self?.showAlert(title: "Success", message: "SSH connection to \(remote.name) works!")
                    } else {
                        let msg = errorOutput.isEmpty ? "Connection failed" : errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        self?.showAlert(title: "Failed", message: msg)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Success" ? .informational : .warning
        alert.addButton(withTitle: "OK")
        if let window = self.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    @objc private func saveConfig() {
        if let field = messageField {
            config.clickMessage = field.stringValue
        }
        config.save()
        onConfigChanged?()
        window?.close()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let identifier = textField.identifier?.rawValue else { return }
        if identifier == "clickMessage" {
            config.clickMessage = textField.stringValue
            return
        }
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
    var clickMessage: String = MaxwellConfig.defaultClickMessage
    var closeButton: NSButton!
    var increaseButton: NSButton!
    var decreaseButton: NSButton!
    var settingsButton: NSButton!
    var trackingArea: NSTrackingArea?
    var aspectRatio: CGFloat = 1.0
    var bubbleWindows: [NSWindow] = []
    var finishedBubbleWindows: [NSWindow] = []
    var bubbleSessions: [SessionInfo] = []
    var onSettingsClick: (() -> Void)?
    var onResize: (() -> Void)?
    var onFinishedBubbleClick: (() -> Void)?
    var onBubbleClick: ((SessionInfo) -> Void)?

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

    func showBubbles(sessions: [SessionInfo]) {
        hideBubbles()

        guard let mainWindow = self.window else { return }

        bubbleSessions = sessions
        let maxBubbleWidth = mainWindow.frame.width
        let minBubbleWidth: CGFloat = 120
        let bubbleHeight: CGFloat = 55
        let spacing: CGFloat = 5
        let padding: CGFloat = 24

        for (index, session) in sessions.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: .medium)
            let lines = session.message.components(separatedBy: "\n")
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
            bubble.message = session.message
            bubble.isClickable = !session.isRemote

            let capturedSession = session
            bubble.onTap = { [weak self] in
                self?.onBubbleClick?(capturedSession)
            }

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
        bubbleSessions.removeAll()
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
        let text = clickMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let meowLabel = NSTextField(labelWithString: text)
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
    var onClaudeWaiting: (([SessionInfo]) -> Void)?
    var onClaudeNotWaiting: (() -> Void)?
    var onClaudeFinished: (([String]) -> Void)?
    var onClaudeFinishedCleared: (() -> Void)?
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

    func dismissFinishedSessions() {
        let doneDir = "/tmp/maxwell_claude_done"
        for session in lastFinishedSessions {
            try? FileManager.default.removeItem(atPath: "\(doneDir)/\(session).json")
        }
        lastFinishedMessages = []
        lastFinishedSessions = []
        onClaudeFinishedCleared?()
    }

    private var lastMessages: [SessionInfo] = []
    private var lastFinishedMessages: [String] = []
    private var lastFinishedSessions: Set<String> = []

    private func checkClaude() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var sessions = self?.checkAllSessions() ?? []
            let remoteSessions = self?.checkRemoteSessions() ?? []
            sessions.append(contentsOf: remoteSessions)

            let (finishedMessages, finishedSessions) = self?.checkFinishedSessions() ?? ([], [])

            DispatchQueue.main.async {
                if !sessions.isEmpty {
                    let currentMessages = sessions.map { $0.message }
                    let lastMessages = self?.lastMessages.map { $0.message } ?? []
                    if currentMessages != lastMessages {
                        self?.lastMessages = sessions
                        self?.onClaudeWaiting?(sessions)
                    }
                } else {
                    if self?.lastState != false {
                        self?.lastState = false
                        self?.lastMessages = []
                        self?.onClaudeNotWaiting?()
                    }
                }
                self?.lastState = !sessions.isEmpty

                if !finishedMessages.isEmpty {
                    if finishedMessages != self?.lastFinishedMessages {
                        self?.lastFinishedMessages = finishedMessages
                        self?.lastFinishedSessions = finishedSessions
                        self?.onClaudeFinished?(finishedMessages)
                    }
                } else if !(self?.lastFinishedMessages.isEmpty ?? true) {
                    self?.lastFinishedMessages = []
                    self?.lastFinishedSessions = []
                    self?.onClaudeFinishedCleared?()
                }
            }
        }
    }

    private func checkRemoteSessions() -> [SessionInfo] {
        var sessions: [SessionInfo] = []
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

                let now = Int(Date().timeIntervalSince1970)
                for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                    guard let jsonData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                          let cwd = json["cwd"] as? String,
                          let time = json["time"] as? Int else {
                        continue
                    }
                    if now - time >= 120 { continue }
                    let message = buildBubbleMessage(json: json, cwd: cwd, serverLabel: "[\(remote.name)] ")
                    sessions.append(SessionInfo(
                        message: message,
                        cwd: cwd,
                        sessionId: json["session"] as? String ?? "",
                        isRemote: true,
                        remoteName: remote.name,
                        tmuxSession: json["tmux"] as? String
                    ))
                }
            } catch {
            }
        }
        return sessions
    }

    private func buildBubbleMessage(json: [String: Any], cwd: String, serverLabel: String) -> String {
        let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
        let tool = json["tool"] as? String
        let cmd = (json["cmd"] as? String) ?? ""
        let toolIcon: String
        switch tool {
        case "Bash": toolIcon = "🖥️"
        case "Edit": toolIcon = "✏️"
        case "Write": toolIcon = "📝"
        case "Read": toolIcon = "📖"
        default: toolIcon = "⚠️"
        }
        let head: String
        if !cmd.isEmpty {
            let shortCmd = cmd.count > 20 ? String(cmd.prefix(20)) + "…" : cmd
            head = "\(toolIcon) \(shortCmd)"
        } else if let tool = tool, !tool.isEmpty {
            head = "\(toolIcon) \(tool)"
        } else if let msg = json["message"] as? String, !msg.isEmpty {
            let shortMsg = msg.count > 26 ? String(msg.prefix(26)) + "…" : msg
            head = "⚠️ \(shortMsg)"
        } else {
            head = "⚠️ Approve?"
        }
        return folder.isEmpty ? "\(serverLabel)\(head)" : "\(serverLabel)\(head)\n📁 \(folder)"
    }

    private func checkAllSessions() -> [SessionInfo] {
        let statusDir = "/tmp/maxwell_claude"
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: statusDir) else {
            return []
        }

        let now = Int(Date().timeIntervalSince1970)
        var found: [(time: Int, info: SessionInfo)] = []

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(statusDir)/\(file)"

            guard let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                  let markerMtime = attrs[.modificationDate] as? Date,
                  let data = fileManager.contents(atPath: filePath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cwd = json["cwd"] as? String,
                  let time = json["time"] as? Int,
                  let session = json["session"] as? String else {
                continue
            }

            // Clear as soon as the session moves past the prompt (approved OR
            // rejected): once the transcript advances beyond when the prompt
            // appeared, the decision has been made. This covers rejects and
            // interrupts, which fire no clearing hook. While the prompt is still
            // open the loop is blocked and the transcript does not advance, so a
            // genuinely-pending bubble is never cleared early.
            if transcriptAdvanced(past: markerMtime, session: session) {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            // Safety net for sessions that died without firing any hook.
            if now - time >= 120 {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            let message = buildBubbleMessage(json: json, cwd: cwd, serverLabel: "")
            found.append((time, SessionInfo(
                message: message,
                cwd: cwd,
                sessionId: session,
                isRemote: false,
                remoteName: nil,
                tmuxSession: json["tmux"] as? String
            )))
        }

        return found.sorted { $0.time < $1.time }.map { $0.info }
    }

    private func transcriptAdvanced(past markerMtime: Date, session: String) -> Bool {
        let fileManager = FileManager.default
        let projectsPath = NSString(string: "~/.claude/projects").expandingTildeInPath
        guard let dirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) else {
            return false
        }
        for dir in dirs {
            let transcriptPath = "\(projectsPath)/\(dir)/\(session).jsonl"
            if let attrs = try? fileManager.attributesOfItem(atPath: transcriptPath),
               let mtime = attrs[.modificationDate] as? Date {
                return mtime.timeIntervalSince1970 > markerMtime.timeIntervalSince1970 + 2
            }
        }
        return false
    }

    private func checkFinishedSessions() -> ([String], Set<String>) {
        let fileManager = FileManager.default
        let doneDir = "/tmp/maxwell_claude_done"
        let statusDir = "/tmp/maxwell_claude"
        let now = Int(Date().timeIntervalSince1970)
        let maxAge = 300

        guard let files = try? fileManager.contentsOfDirectory(atPath: doneDir) else {
            return ([], [])
        }

        var found: [(time: Int, message: String, session: String)] = []

        for file in files where file.hasSuffix(".json") {
            let filePath = "\(doneDir)/\(file)"
            guard let data = fileManager.contents(atPath: filePath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let time = json["time"] as? Int,
                  let session = json["session"] as? String else {
                continue
            }

            if now - time >= maxAge {
                try? fileManager.removeItem(atPath: filePath)
                continue
            }

            // A live "waiting for approval" state takes priority over "done".
            if fileManager.fileExists(atPath: "\(statusDir)/\(session).json") {
                continue
            }

            let cwd = json["cwd"] as? String ?? ""
            let folder = cwd.components(separatedBy: "/").suffix(2).joined(separator: "/")
            let prompt = json["prompt"] as? String ?? ""
            let shortPrompt = prompt.count > 30 ? String(prompt.prefix(30)) + "…" : prompt
            let head = shortPrompt.isEmpty ? "✅ done" : "✅ \(shortPrompt)"
            let message = folder.isEmpty ? head : "\(head)\n📁 \(folder)"
            found.append((time, message, session))
        }

        found.sort { $0.time < $1.time }
        return (found.map { $0.message }, Set(found.map { $0.session }))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var containerView: HoverView!
    var claudeMonitor: ClaudeMonitor!
    var settingsController: SettingsWindowController!
    var gifView: AnimatedGIFView!
    var telegramNotifier: TelegramNotifier!
    var originalY: CGFloat = 0
    var jumpTimer: Timer?
    var hasBubbles: Bool = false
    var hasFinishedBubbles: Bool = false
    var currentTheme: String = MaxwellConfig.defaultTheme

    func applicationDidFinishLaunching(_ notification: Notification) {
        ThemeManager.seedIfNeeded()
        let config = MaxwellConfig.load()
        currentTheme = config.theme

        settingsController = SettingsWindowController()
        settingsController.onConfigChanged = { [weak self] in
            self?.claudeMonitor.reloadConfig()
            self?.applyConfig()
        }

        guard let gifURL = ThemeManager.gifURL(for: config.theme),
              let gifData = try? Data(contentsOf: gifURL),
              let image = NSImage(data: gifData) else {
            print("Failed to load gif for theme \(config.theme)")
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
        containerView.clickMessage = config.clickMessage
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

        telegramNotifier = TelegramNotifier()
        telegramNotifier.start()

        claudeMonitor = ClaudeMonitor()
        claudeMonitor.onClaudeWaiting = { [weak self] sessions in
            self?.showNotifications(sessions: sessions)
            let remotes = MaxwellConfig.load().remotes
            self?.telegramNotifier.sendWaitingNotification(sessions: sessions, remotes: remotes)
        }
        claudeMonitor.onClaudeNotWaiting = { [weak self] in
            self?.hideNotifications()
            self?.telegramNotifier.clearNotifiedMessages()
        }
        claudeMonitor.onClaudeFinished = { [weak self] messages in
            self?.showFinishedNotifications(messages: messages)
        }
        claudeMonitor.onClaudeFinishedCleared = { [weak self] in
            self?.hideFinishedNotifications()
        }
        claudeMonitor.start()

        containerView.onBubbleClick = { [weak self] session in
            self?.switchToApp(for: session)
        }
    }

    func showNotifications(sessions: [SessionInfo]) {
        containerView.showBubbles(sessions: sessions)
        startJumping()
    }

    func switchToApp(for session: SessionInfo) {
        if session.isRemote {
            return
        }

        let cwd = session.cwd

        DispatchQueue.global(qos: .userInitiated).async {
            let codeProcess = Process()
            codeProcess.launchPath = "/usr/bin/env"
            codeProcess.arguments = ["code", "-r", "-g", "\(cwd)/."]
            codeProcess.standardOutput = FileHandle.nullDevice
            codeProcess.standardError = FileHandle.nullDevice

            do {
                try codeProcess.run()
                codeProcess.waitUntilExit()

                if codeProcess.terminationStatus != 0 {
                    let openProcess = Process()
                    openProcess.launchPath = "/usr/bin/open"
                    openProcess.arguments = ["-a", "Visual Studio Code", cwd]
                    openProcess.standardOutput = FileHandle.nullDevice
                    openProcess.standardError = FileHandle.nullDevice
                    try? openProcess.run()
                    openProcess.waitUntilExit()
                }
            } catch {
                let openProcess = Process()
                openProcess.launchPath = "/usr/bin/open"
                openProcess.arguments = ["-a", "Visual Studio Code", cwd]
                openProcess.standardOutput = FileHandle.nullDevice
                openProcess.standardError = FileHandle.nullDevice
                try? openProcess.run()
            }
        }
    }

    func hideNotifications() {
        containerView.hideBubbles()
        stopJumping()
    }

    func showFinishedNotifications(messages: [String]) {
        let config = MaxwellConfig.load()
        guard config.showDoneBubbles else { return }
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

            if currentStep >= steps {
                timer.invalidate()
                self.window.setFrameOrigin(NSPoint(x: self.window.frame.origin.x, y: self.originalY))
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

    private func applyConfig() {
        let config = MaxwellConfig.load()
        gifView.speed = config.gifSpeed
        containerView.clickMessage = config.clickMessage
        if !config.showDoneBubbles {
            hideFinishedNotifications()
        }
        if config.theme != currentTheme {
            reloadGif(theme: config.theme)
        }
    }

    private func reloadGif(theme: String) {
        guard let url = ThemeManager.gifURL(for: theme),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data), image.size.height > 0 else { return }
        currentTheme = theme

        let aspect = image.size.width / image.size.height
        containerView.aspectRatio = aspect
        gifView.loadGIF(from: url)

        var frame = window.frame
        let newHeight = frame.width / aspect
        frame.origin.y += frame.height - newHeight
        frame.size.height = newHeight
        window.setFrame(frame, display: true)
        saveWindowFrame()
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
