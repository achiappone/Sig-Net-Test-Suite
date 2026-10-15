import SwiftUI

/// Popup table for the manufacturer TID table (ManufacturerTIDs): one row per TID, edited in place and saved to its
/// JSON file. Choices and fields are written as "label=hex; label=hex" and "name:bytes; name:bytes".
struct ManufacturerTIDsEditor: View {
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row] = ManufacturerTIDs.entries.map(Row.init)
    @State private var error: String?

    struct Row: Identifiable {
        let id = UUID()
        var esta = "", tid = "", name = "", min = "", max = "", bytes = "", choices = "", fields = "", confirm = ""
        var getOnly = false

        init() {}
        init(_ e: ManufacturerTIDs.Entry) {
            esta = e.esta; tid = e.tid; name = e.name
            min = e.min.map(String.init) ?? ""; max = e.max.map(String.init) ?? ""; bytes = e.bytes.map(String.init) ?? ""
            choices = (e.choices ?? []).map { "\($0.label)=\($0.hex)" }.joined(separator: "; ")
            fields = (e.fields ?? []).map { "\($0.name):\($0.bytes)" }.joined(separator: "; ")
            confirm = e.confirm ?? ""
            getOnly = e.settable == false
        }

        /// The entry, or why it isn't one.
        func entry(_ n: Int) -> Result<ManufacturerTIDs.Entry, Problem> {
            func fail(_ s: String) -> Result<ManufacturerTIDs.Entry, Problem> { .failure(Problem(text: "Row \(n): \(s)")) }
            func hex16(_ s: String) -> UInt16? { UInt16(s.lowercased().replacingOccurrences(of: "0x", with: ""), radix: 16) }
            func parts(_ s: String) -> [String] { s.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            let esta = esta.trimmingCharacters(in: .whitespaces), tid = tid.trimmingCharacters(in: .whitespaces)
            guard hex16(esta) != nil else { return fail("ESTA ID must be 4 hex digits") }
            guard let t = hex16(tid), t >= 0x8000, t <= 0xFF00 else { return fail("TID must be hex 8000–FF00") }
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return fail("needs a name") }
            let lo = Int64(min.trimmingCharacters(in: .whitespaces)), hi = Int64(max.trimmingCharacters(in: .whitespaces))
            if (!min.isEmpty && lo == nil) || (!max.isEmpty && hi == nil) { return fail("min and max must be whole numbers") }
            if let lo, let hi, lo > hi { return fail("min is above max") }
            let size = Int(bytes.trimmingCharacters(in: .whitespaces))
            if !bytes.isEmpty && ![1, 2, 4].contains(size ?? 0) { return fail("bytes must be 1, 2 or 4") }
            var cs: [ManufacturerTIDs.Choice] = []
            for p in parts(choices) {
                guard let eq = p.lastIndex(of: "=") else { return fail("choice \"\(p)\" needs label=hex") }
                let label = p[..<eq].trimmingCharacters(in: .whitespaces), hex = p[p.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                guard !label.isEmpty, hex.count % 2 == 0, !hex.isEmpty, hex.allSatisfy(\.isHexDigit) else { return fail("choice \"\(p)\" needs label=hex") }
                cs.append(.init(label: label, hex: hex))
            }
            var fs: [ManufacturerTIDs.Field] = []
            for p in parts(fields) {
                let kv = p.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard kv.count == 2, !kv[0].isEmpty, let b = Int(kv[1]), b > 0 else { return fail("field \"\(p)\" needs name:bytes") }
                fs.append(.init(name: kv[0], bytes: b))
            }
            let c = confirm.trimmingCharacters(in: .whitespaces)
            return .success(.init(esta: esta, tid: tid, name: name.trimmingCharacters(in: .whitespaces),
                                  settable: getOnly ? false : nil, min: lo, max: hi, bytes: size,
                                  choices: cs.isEmpty ? nil : cs, fields: fs.isEmpty ? nil : fs, confirm: c.isEmpty ? nil : c))
        }
    }

    struct Problem: Error { let text: String }

    private let widths: [(String, CGFloat)] = [("ESTA", 56), ("TID", 56), ("Name", 150), ("GET only", 60), ("Min", 60), ("Max", 60),
                                               ("Bytes", 44), ("Choices  label=hex; …", 200), ("Fields  name:bytes; …", 200), ("Confirm before SET", 200), ("", 24)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manufacturer parameters").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
            Text("A manufacturer TID only means something under its maker's ESTA ID. Leave Min/Max empty to SET raw hex.")
                .font(.system(size: 11)).foregroundStyle(Color.silk)
            ScrollView([.vertical, .horizontal]) {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        ForEach(widths, id: \.0) { Text($0.0).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.silk).frame(width: $0.1, alignment: .leading) }
                    }
                    ForEach($rows) { $r in
                        GridRow {
                            cell($r.esta, "21A4", 56); cell($r.tid, "8001", 56); cell($r.name, "Name", 150)
                            Toggle("", isOn: $r.getOnly).labelsHidden().frame(width: 60)
                            cell($r.min, "", 60); cell($r.max, "", 60); cell($r.bytes, "1", 44)
                            cell($r.choices, "Off=00; On=01", 200); cell($r.fields, "Status:1; Count:2", 200); cell($r.confirm, "", 200)
                            Button { rows.removeAll { $0.id == r.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help("Remove this row").frame(width: 24)
                        }
                    }
                }
                .padding(2)
            }
            .frame(minHeight: 220)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(Color.red) }
            HStack {
                Button("Add row") { rows.append(Row()) }.buttonStyle(.softKey)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.softKey).keyboardShortcut(.cancelAction)
                Button("Save", action: save).buttonStyle(.softKey).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 1180, minHeight: 360)
        .background(Color.faceplate)
    }

    private func cell(_ text: Binding<String>, _ prompt: String, _ width: CGFloat) -> some View {
        TextField(prompt, text: text).textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced)).frame(width: width)
    }

    private func save() {
        var list: [ManufacturerTIDs.Entry] = []
        for (i, r) in rows.enumerated() {
            switch r.entry(i + 1) {
            case .success(let e): list.append(e)
            case .failure(let p): error = p.text; return
            }
        }
        do {
            try ManufacturerTIDs.save(list)
            onSave()
            dismiss()
        } catch {
            self.error = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
