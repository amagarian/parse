import Foundation

struct ReceiptItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var price: Double
    var quantity: Int
    var claimedBy: [String]
    /// Per-person split overrides. Key = person name, value = denominator.
    /// E.g. ["Alex": 2] means Alex pays price/2 regardless of claimedBy.count.
    var splitOverrides: [String: Int]

    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1, claimedBy: [String] = [], splitOverrides: [String: Int] = [:]) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
        self.claimedBy = claimedBy
        self.splitOverrides = splitOverrides
    }

    func priceForPerson(_ name: String) -> Double {
        guard claimedBy.contains(name) else { return 0 }
        if let override = splitOverrides[name] {
            return price / Double(max(1, override))
        }
        return pricePerClaimant
    }

    var pricePerClaimant: Double {
        guard !claimedBy.isEmpty else { return price }
        return price / Double(claimedBy.count)
    }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
}
