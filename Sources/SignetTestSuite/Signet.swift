import Combine
import Foundation
import Security
import SigNet

/// SigNet's settings and Manager engines, observable for SwiftUI.
final class SecuritySettings: SecurityConfig, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private var saveQueued = false
    /// What the Keychain holds. Only a real change is written, so a failed or denied read never deletes the item.
    private var savedPassphrase = ""
    /// Snapshot's --passphrase, --scope and --interface are for that run only; they never replace the saved settings.
    private let persist = !Snapshot.args.contains { ["--passphrase", "--scope", "--interface"].contains($0) }

    /// Restores the last mode, scope and passphrase, so a relaunch talks to the same network. main.swift restores the NIC.
    override init() {
        super.init()
        let d = UserDefaults.standard
        mode = d.string(forKey: "security.mode").flatMap(SecurityMode.init(rawValue:)) ?? .open
        scope = d.string(forKey: "security.scope") ?? scope
        passphrase = Keychain.read() ?? ""
        savedPassphrase = passphrase
    }

    override func willChange() {
        objectWillChange.send()
        // willChange fires before the new value lands; save once it has, and once per burst of keystrokes.
        guard persist, !saveQueued else { return }
        saveQueued = true
        DispatchQueue.main.async { [self] in
            saveQueued = false
            let d = UserDefaults.standard
            d.set(mode.rawValue, forKey: "security.mode")
            d.set(scope, forKey: "security.scope")
            if passphrase != savedPassphrase {
                Keychain.write(passphrase)
                savedPassphrase = passphrase
            }
        }
    }
}

/// The passphrase, in the login Keychain rather than preferences: it derives every Sig-Net key.
private enum Keychain {
    private static let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword, kSecAttrService: "Sig-Net Test Suite", kSecAttrAccount: "passphrase",
    ]

    static func read() -> String? {
        var q = query
        q[kSecReturnData] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ passphrase: String) {
        guard !passphrase.isEmpty else { SecItemDelete(query as CFDictionary); return }
        let data = Data(passphrase.utf8)
        if SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary) == errSecItemNotFound {
            var q = query
            q[kSecValueData] = data
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}

final class Manager: ManagerEngine, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    override func willChange() { objectWillChange.send() }
    var securitySettings: SecuritySettings { settings as! SecuritySettings } // the app only makes Managers with these
}
