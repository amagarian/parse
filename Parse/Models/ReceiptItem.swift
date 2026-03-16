import Foundation

struct ReceiptItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var price: Double
    var quantity: Int
    var claimedBy: [String]

    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1, claimedBy: [String] = []) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
        self.claimedBy = claimedBy
    }

    var pricePerClaimant: Double {
        guard !claimedBy.isEmpty else { return price }
        return price / Double(claimedBy.count)
    }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }
}
