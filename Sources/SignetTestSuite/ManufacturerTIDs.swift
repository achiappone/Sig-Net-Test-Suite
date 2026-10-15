import Foundation

/// Names and SET ranges for manufacturer TIDs (0x8000-0xFF00). Sig-Net carries none: a manufacturer TID means what its
/// maker's own spec says, and only under that maker's ESTA ID (PF §10.1.2). So they come from this table, a JSON file
/// the user edits in the app (Parameters → Other parameters → Edit), written the first time they save there.
enum ManufacturerTIDs {
    /// One TID. `esta` and `tid` are hex ("7FF0", "8001"). With `min`/`max` the value is a big-endian number of `bytes`
    /// bytes (1, 2 or 4; default 1) set on the keypad within that range; without them it is raw hex. `settable: false`
    /// = GET only.
    struct Entry: Codable {
        var esta: String
        var tid: String
        var name: String
        var settable: Bool?
        var min: Int64?
        var max: Int64?
        var bytes: Int?
        /// Named SET values, e.g. [{"label": "Start", "hex": "50544348"}]: shown as a choice instead of a hex field.
        var choices: [Choice]?
        /// Names for the parts of the GET value, in order, e.g. [{"name": "Patched", "bytes": 2}]: "Patched 3 · …".
        var fields: [Field]?
        /// Asked before a SET is sent (not for an all-zero "no"), e.g. what it will do to the rig. Cancel is the default.
        var confirm: String?
    }

    struct Choice: Codable { var label: String; var hex: String }
    struct Field: Codable { var name: String; var bytes: Int }

    /// Empty: the app knows no manufacturer's TIDs. Users add their own to the JSON file.
    static let defaults: [Entry] = []

    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sig-Net Test Suite/manufacturer-tids.json")
    }

    /// The table, and why the file couldn't be read when it couldn't (the built-in defaults are in use meanwhile).
    private static var state: (entries: [Entry], problem: String?) = load()
    static var entries: [Entry] { state.entries }
    static var problem: String? { state.problem }

    /// Write the table and use it straight away.
    static func save(_ list: [Entry]) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try enc.encode(list).write(to: url, options: .atomic)
        state = (list, nil)
    }

    static func entry(esta: UInt16, tid: UInt16) -> Entry? {
        entries.first { hex($0.esta) == esta && hex($0.tid) == tid }
    }

    private static func hex(_ s: String) -> UInt16? {
        UInt16(s.lowercased().replacingOccurrences(of: "0x", with: "").trimmingCharacters(in: .whitespaces), radix: 16)
    }

    private static func load() -> (entries: [Entry], problem: String?) {
        guard FileManager.default.fileExists(atPath: url.path) else { return (defaults, nil) } // nothing saved yet
        do {
            return (try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url)), nil)
        } catch {
            return (defaults, "manufacturer-tids.json: \(error.localizedDescription)")
        }
    }
}
