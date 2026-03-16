import Foundation

struct SplitSession: Codable, Identifiable, Equatable {
    var id: UUID
    var items: [ReceiptItem]
    var subtotal: Double
    var tax: Double
    var tip: Double
    var venmoUsername: String
    var hostName: String
    var restaurantName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        items: [ReceiptItem] = [],
        subtotal: Double = 0,
        tax: Double = 0,
        tip: Double = 0,
        venmoUsername: String = "",
        hostName: String = "",
        restaurantName: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.venmoUsername = venmoUsername
        self.hostName = hostName
        self.restaurantName = restaurantName
        self.createdAt = createdAt
    }

    var total: Double {
        subtotal + tax + tip
    }

    var taxRate: Double {
        guard subtotal > 0 else { return 0 }
        return tax / subtotal
    }

    var tipRate: Double {
        guard subtotal > 0 else { return 0 }
        return tip / subtotal
    }

    func totalForPerson(_ personName: String) -> Double {
        let itemsTotal = items
            .filter { $0.claimedBy.contains(personName) }
            .reduce(0.0) { $0 + $1.pricePerClaimant }

        let proportionalTax = itemsTotal * taxRate
        let proportionalTip = itemsTotal * tipRate

        return itemsTotal + proportionalTax + proportionalTip
    }

    func itemsForPerson(_ personName: String) -> [ReceiptItem] {
        items.filter { $0.claimedBy.contains(personName) }
    }

    var allClaimants: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            for name in item.claimedBy {
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    // MARK: — Compact Encoding (v2)
    //
    // Format (newline-separated, tabs within item lines):
    //   Line 0:  "p2"              (format version sentinel)
    //   Line 1:  restaurantName
    //   Line 2:  hostName
    //   Line 3:  venmoUsername
    //   Line 4:  subtotal
    //   Line 5:  tax
    //   Line 6:  tip
    //   Lines 7+: name\tprice\tqty\tclaimer1,claimer2,...
    //
    // The raw string is UTF-8 base64url-encoded (no padding, - instead of +, _ instead of /).
    // This is ~5x smaller than the old JSON+base64 approach, yielding a scannable QR code.

    func toCompactString() -> String? {
        var lines: [String] = [
            "p2",
            restaurantName,
            hostName,
            venmoUsername,
            String(format: "%.2f", subtotal),
            String(format: "%.2f", tax),
            String(format: "%.2f", tip),
        ]
        for item in items {
            let claimed = item.claimedBy.joined(separator: ",")
            lines.append("\(item.name)\t\(String(format: "%.2f", item.price))\t\(item.quantity)\t\(claimed)")
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromCompactString(_ string: String) -> SplitSession? {
        // Normalise URL-safe base64 back to standard
        var b64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }

        guard let data = Data(base64Encoded: b64),
              let text = String(data: data, encoding: .utf8) else { return nil }

        if text.hasPrefix("p2") {
            return decodeV2(text)
        }

        // Fallback: legacy JSON blob
        return fromJSON(data)
    }

    private static func decodeV2(_ text: String) -> SplitSession? {
        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 7 else { return nil }

        let restaurantName  = lines[1]
        let hostName        = lines[2]
        let venmoUsername   = lines[3]
        let subtotal        = Double(lines[4]) ?? 0
        let tax             = Double(lines[5]) ?? 0
        let tip             = Double(lines[6]) ?? 0

        var items: [ReceiptItem] = []
        for line in lines.dropFirst(7) {
            guard !line.isEmpty else { continue }
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3,
                  let price = Double(parts[1]),
                  let qty   = Int(parts[2]) else { continue }
            let claimed = parts.count > 3
                ? parts[3].components(separatedBy: ",").filter { !$0.isEmpty }
                : []
            items.append(ReceiptItem(name: parts[0], price: price, quantity: qty, claimedBy: claimed))
        }

        return SplitSession(
            items: items, subtotal: subtotal, tax: tax, tip: tip,
            venmoUsername: venmoUsername, hostName: hostName,
            restaurantName: restaurantName
        )
    }

    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }

    static func fromJSON(_ data: Data) -> SplitSession? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SplitSession.self, from: data)
    }
}
