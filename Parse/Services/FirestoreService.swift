import Foundation
import FirebaseCore
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private var db: Firestore? { FirebaseApp.app() != nil ? Firestore.firestore() : nil }
    private let col = "sessions"

    // MARK: - Write

    /// Creates (or overwrites) the session document in Firestore.
    /// Called by the host when the QR share screen first appears.
    func createSession(_ session: SplitSession) async throws {
        guard let db else { return }
        try await db.collection(col).document(session.id.uuidString).setData(encode(session))
    }

    /// Updates only the items array (claimed-by lists).
    /// Called by guests after confirming their item selection.
    func updateClaims(sessionId: String, items: [ReceiptItem]) async throws {
        guard let db else { return }
        let data: [String: Any] = ["items": items.map { encodeItem($0) }]
        // merge: true so this works even if the host doc hasn't landed yet
        try await db.collection(col).document(sessionId).setData(data, merge: true)
    }

    /// Atomically adds a guest name to the participants array.
    func addParticipant(sessionId: String, name: String) async throws {
        guard let db else { return }
        try await db.collection(col).document(sessionId).setData(
            ["participants": FieldValue.arrayUnion([name])],
            merge: true
        )
    }

    // MARK: - Listen

    /// Attaches a real-time snapshot listener. Returns the handle so the caller
    /// can remove it in onDisappear.
    func listen(to sessionId: String, onChange: @escaping (SplitSession) -> Void) -> ListenerRegistration? {
        guard let db else { return nil }
        return db.collection(col).document(sessionId).addSnapshotListener { snap, error in
            guard let snap, snap.exists,
                  let data = snap.data(),
                  let session = Self.decode(data, id: sessionId) else { return }
            DispatchQueue.main.async { onChange(session) }
        }
    }

    // MARK: - Encode

    private func encode(_ s: SplitSession) -> [String: Any] {
        [
            "restaurantName": s.restaurantName,
            "hostName":       s.hostName,
            "venmoUsername":  s.venmoUsername,
            "subtotal":       s.subtotal,
            "tax":            s.tax,
            "tip":            s.tip,
            "fees":           s.fees,
            "createdAt":      Timestamp(date: s.createdAt),
            "participants":   s.participants,
            "items":          s.items.map { encodeItem($0) }
        ]
    }

    private func encodeItem(_ i: ReceiptItem) -> [String: Any] {
        var dict: [String: Any] = [
            "id":        i.id.uuidString,
            "name":      i.name,
            "price":     i.price,
            "quantity":  i.quantity,
            "claimedBy": i.claimedBy
        ]
        if !i.splitOverrides.isEmpty {
            dict["splitOverrides"] = i.splitOverrides
        }
        return dict
    }

    // MARK: - Decode

    private static func decode(_ data: [String: Any], id: String) -> SplitSession? {
        guard let restaurant = data["restaurantName"] as? String,
              let host       = data["hostName"]       as? String,
              let venmo      = data["venmoUsername"]  as? String,
              let subtotal   = data["subtotal"]       as? Double,
              let tax        = data["tax"]            as? Double,
              let tip        = data["tip"]            as? Double,
              let rawItems   = data["items"]          as? [[String: Any]] else { return nil }
        let fees = data["fees"] as? Double ?? 0

        let items = rawItems.compactMap { d -> ReceiptItem? in
            guard let name     = d["name"]     as? String,
                  let price    = d["price"]    as? Double,
                  let quantity = d["quantity"] as? Int else { return nil }
            let claimed = d["claimedBy"] as? [String] ?? []
            let uuid    = (d["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            var splits: [String: Int] = [:]
            if let rawSplits = d["splitOverrides"] as? [String: Any] {
                for (k, v) in rawSplits {
                    if let intVal = v as? Int { splits[k] = intVal }
                    else if let numVal = v as? NSNumber { splits[k] = numVal.intValue }
                }
            }
            return ReceiptItem(id: uuid, name: name, price: price,
                               quantity: quantity, claimedBy: claimed, splitOverrides: splits)
        }

        let participants = data["participants"] as? [String] ?? []
        return SplitSession(
            id: UUID(uuidString: id) ?? UUID(),
            items: items, subtotal: subtotal, tax: tax, tip: tip, fees: fees,
            venmoUsername: venmo, hostName: host, restaurantName: restaurant,
            participants: participants
        )
    }
}
