import Cocoa
import Carbon

public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    public var onHotkeyPressed: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private let hotKeyID = EventHotKeyID(signature: 0x50535253, id: 1) // "PSRS", 1
    
    private let keyCodeKey = "psrshot_hotkey_keycode"
    private let modifiersKey = "psrshot_hotkey_modifiers"
    
    private init() {
        installCarbonEventHandler()
    }
    
    deinit {
        unregisterCurrentHotKey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    // MARK: - Setup & Handler
    
    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                var receivedID = EventHotKeyID()
                let result = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                
                if result == noErr && receivedID.signature == 0x50535253 && receivedID.id == 1 {
                    DispatchQueue.main.async {
                        HotkeyManager.shared.onHotkeyPressed?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if status != noErr {
            NSLog("[HotkeyManager] Failed to install Carbon event handler: %d", status)
        }
    }
    
    // MARK: - Registration
    
    public func registerDefaultOrSaved() {
        let (keyCode, carbonModifiers) = loadSavedHotkey()
        register(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }
    
    public func register(keyCode: UInt32, carbonModifiers: UInt32) {
        unregisterCurrentHotKey()
        
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        if status == noErr {
            hotKeyRef = ref
            saveHotkey(keyCode: keyCode, carbonModifiers: carbonModifiers)
            NSLog("[HotkeyManager] Registered hotkey keyCode: %d, modifiers: %d", keyCode, carbonModifiers)
        } else {
            NSLog("[HotkeyManager] Failed to register hotkey. Status: %d", status)
        }
    }
    
    public func unregisterCurrentHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    // MARK: - Persistence
    
    public func loadSavedHotkey() -> (keyCode: UInt32, carbonModifiers: UInt32) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: keyCodeKey) != nil {
            let code = UInt32(defaults.integer(forKey: keyCodeKey))
            let mods = UInt32(defaults.integer(forKey: modifiersKey))
            return (code, mods)
        }
        // Default: Cmd + Shift + X (kVK_ANSI_X = 0x07)
        let defaultCode = UInt32(kVK_ANSI_X)
        let defaultMods = UInt32(cmdKey | shiftKey)
        return (defaultCode, defaultMods)
    }
    
    private func saveHotkey(keyCode: UInt32, carbonModifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(carbonModifiers), forKey: modifiersKey)
    }
    
    // MARK: - Helper Conversions
    
    public static func carbonModifiers(from cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if cocoaFlags.contains(.command) { mods |= UInt32(cmdKey) }
        if cocoaFlags.contains(.shift) { mods |= UInt32(shiftKey) }
        if cocoaFlags.contains(.option) { mods |= UInt32(optionKey) }
        if cocoaFlags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
    
    public static func displayString(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var result = ""
        if (carbonModifiers & UInt32(controlKey)) != 0 { result += "⌃" }
        if (carbonModifiers & UInt32(optionKey)) != 0 { result += "⌥" }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { result += "⇧" }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { result += "⌘" }
        
        result += keyString(for: keyCode)
        return result
    }
    
    public static func keyString(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key(\(keyCode))"
        }
    }
}
