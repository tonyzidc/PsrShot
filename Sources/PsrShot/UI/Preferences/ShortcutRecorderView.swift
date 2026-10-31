import Cocoa
import Carbon

public final class ShortcutRecorderView: NSView {
    public var onShortcutChanged: ((UInt32, UInt32) -> Void)?
    
    private var isRecording: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    private var currentKeyCode: UInt32 = UInt32(kVK_ANSI_X)
    private var currentModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    
    private let label = NSTextField(labelWithString: "⌘⇧X")
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1.0
        
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        let (code, mods) = HotkeyManager.shared.loadSavedHotkey()
        setShortcut(keyCode: code, carbonModifiers: mods)
        updateAppearance()
    }
    
    public func setShortcut(keyCode: UInt32, carbonModifiers: UInt32) {
        self.currentKeyCode = keyCode
        self.currentModifiers = carbonModifiers
        label.stringValue = HotkeyManager.displayString(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }
    
    private func updateAppearance() {
        if isRecording {
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
            layer?.borderColor = NSColor.systemBlue.cgColor
            label.stringValue = "Press shortcut..."
            label.textColor = .systemBlue
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            label.stringValue = HotkeyManager.displayString(keyCode: currentKeyCode, carbonModifiers: currentModifiers)
            label.textColor = .labelColor
        }
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }
    
    public override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }
    
    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        // Escape cancels recording
        if event.keyCode == 53 {
            isRecording = false
            return
        }
        
        let cocoaMods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let carbonMods = HotkeyManager.carbonModifiers(from: cocoaMods)
        
        // Require at least one modifier key
        guard carbonMods != 0 else {
            NSSound.beep()
            return
        }
        
        let code = UInt32(event.keyCode)
        setShortcut(keyCode: code, carbonModifiers: carbonMods)
        isRecording = false
        
        HotkeyManager.shared.register(keyCode: code, carbonModifiers: carbonMods)
        onShortcutChanged?(code, carbonMods)
    }
}
