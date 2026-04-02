import Foundation

class ReceiptParser {
    struct ParsedReceipt {
        var items: [ReceiptItem]
        var subtotal: Double?
        var tax: Double?
        var total: Double?
        var tip: Double?
        var fees: Double?
        var restaurantName: String?
        var debugLog: [(line: String, verdict: String)] = []
    }

    private static let summaryPatterns: [(pattern: String, type: SummaryType)] = [
        ("sub.?total", .subtotal),
        ("sales.?tax", .tax),
        ("^tax", .tax),
        ("\\bhst\\b", .tax),
        ("\\bgst\\b", .tax),
        ("\\bvat\\b", .tax),
        ("gratuity", .tip),
        ("^tip", .tip),
        ("service charge", .tip),
        ("grand.?total", .total),
        ("total.?due", .total),
        ("amount.?due", .total),
        ("net.?total", .subtotal),
        ("^total", .total),
        ("^amt\\b", .total),
        ("^amount\\b", .total),
        ("balance.?due", .total),
        // Surcharges / flat fees split evenly among all diners
        ("surcharge", .fees),
        ("processing.?fee", .fees),
        ("convenience.?fee", .fees),
        ("credit.?card.?fee", .fees),
        ("card.?fee", .fees),
        ("admin.?fee", .fees),
        ("administrative.?fee", .fees),
        ("facility.?fee", .fees),
        ("wellness.?fee", .fees),
        ("healthcare.?surcharge", .fees),
    ]

    private enum SummaryType { case subtotal, tax, tip, total, fees }

    private static let noisePatterns: [String] = [
        "cash", "credit", "debit", "visa", "mastercard", "amex",
        "card", "entry", "contactless", "approved",
        "thank you", "thanks", "please come", "have a nice",
        "server:", "check.?#", "guests?:", "table:",
        "receipt:", "invoice",
        "\\btel[.:\\s]", "phone:", "fax:", "www\\.", "http", "\\.com",
        "ref:", "auth", "status:",
        "invalid", "date",
        "^qty\\b", "^desc\\b", "^item\\b", "^price\\b",
        "purchase",
    ]

    static func parse(lines: [String]) -> ParsedReceipt {
        var items: [ReceiptItem] = []
        var subtotal: Double?
        var tax: Double?
        var total: Double?
        var tip: Double?
        var fees: Double?
        var debugLog: [(line: String, verdict: String)] = []

        let paired = pairOrphanLines(lines)
        let isNumberedList = detectsNumberedList(in: paired)

        for line in paired {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()

            guard !lower.isEmpty, lower.count > 1 else {
                debugLog.append((line: trimmed, verdict: "skip: empty"))
                continue
            }
            guard !isNoise(lower) else {
                debugLog.append((line: trimmed, verdict: "skip: NOISE"))
                continue
            }
            guard let price = extractPrice(from: trimmed) else {
                debugLog.append((line: trimmed, verdict: "skip: no price"))
                continue
            }
            if let summaryType = matchSummaryType(lower) {
                switch summaryType {
                case .subtotal: subtotal = price
                case .tax:      tax = price
                case .tip:      tip = price
                case .total:    total = price
                case .fees:     fees = (fees ?? 0) + price
                }
                debugLog.append((line: trimmed, verdict: "summary: \(summaryType)"))
                continue
            }
            let name = cleanItemName(trimmed)
            if !name.isEmpty && name.count > 1 && price > 0 && price < 10000 {
                let quantity = isNumberedList ? 1 : extractQuantity(from: trimmed)
                items.append(ReceiptItem(name: name, price: price, quantity: quantity))
                debugLog.append((line: trimmed, verdict: "ITEM: \(name) $\(price) qty\(quantity)"))
            } else {
                debugLog.append((line: trimmed, verdict: "skip: bad name '\(name)' or price \(price)"))
            }
        }

        // Cross-check: determine a reference subtotal from a detected summary line
        // or derive one from total − tax − tip − fees.
        var referenceSubtotal = subtotal
        if referenceSubtotal == nil, let t = total {
            let derived = t - (tax ?? 0) - (tip ?? 0) - (fees ?? 0)
            if derived > 0 { referenceSubtotal = derived }
        }

        // If items sum significantly exceeds the reference, receipt category
        // subtotals (e.g. "Food", "Beverage") were likely parsed as items.
        // Remove items from the bottom up — categories always appear after the
        // individual items — until the sum matches.
        if let ref = referenceSubtotal, !items.isEmpty {
            let itemSum = items.reduce(0.0) { $0 + $1.price }
            var excess = itemSum - ref
            if excess > 0.50 {
                var toRemove: [Int] = []
                for i in stride(from: items.count - 1, through: 0, by: -1) {
                    guard excess > 0.01 else { break }
                    if items[i].price <= excess + 0.01 {
                        toRemove.append(i)
                        excess -= items[i].price
                    }
                }
                if abs(excess) < 0.50 {
                    for i in toRemove.sorted().reversed() {
                        debugLog.append((line: items[i].name, verdict: "pruned: category subtotal"))
                        items.remove(at: i)
                    }
                }
            }
        }

        if subtotal == nil && !items.isEmpty {
            subtotal = items.reduce(0) { $0 + $1.price }
        }

        // Most receipts include surcharges/fees in the subtotal line (they appear
        // as line items above the subtotal). Back them out so fees aren't double-counted.
        if let f = fees, let s = subtotal, f > 0 {
            subtotal = max(0, s - f)
        }

        if tax == nil, let st = subtotal, let t = total, t > st {
            tax = t - st
        }

        let restaurantName = extractRestaurantName(from: lines)

        return ParsedReceipt(items: items, subtotal: subtotal, tax: tax, total: total, tip: tip, fees: fees, restaurantName: restaurantName, debugLog: debugLog)
    }

    private static func extractPrice(from line: String) -> Double? {
        let patterns = [
            #"\$(\d+\.\d{2})"#,
            #"(\d+\.\d{2})\s*$"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line),
               let value = Double(line[range]) {
                return value
            }
        }
        return nil
    }

    /// Merges consecutive line pairs where the first has text but no price and
    /// the second has a price but no letters — a common OCR split for wide
    /// two-column receipts where name and price land on slightly different baselines.
    private static func pairOrphanLines(_ lines: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let hasPrice   = extractPrice(from: line) != nil
            let hasLetters = line.filter(\.isLetter).count > 0

            if hasLetters && !hasPrice && i + 1 < lines.count {
                let next           = lines[i + 1]
                let nextHasPrice   = extractPrice(from: next) != nil
                let nextHasLetters = next.filter(\.isLetter).count > 0
                if nextHasPrice && !nextHasLetters {
                    result.append(line + " " + next)
                    i += 2
                    continue
                }
            }
            result.append(line)
            i += 1
        }
        return result
    }

    /// Returns true when the item lines on this receipt use a sequential numbered
    /// list format (01, 02, 03 … or 1, 2, 3 …), meaning leading numbers are
    /// print-order bullets rather than item quantities.
    private static func detectsNumberedList(in lines: [String]) -> Bool {
        let leadingNumRegex = try? NSRegularExpression(pattern: #"^(\d{1,2})[\s\.]"#)
        var sequence: [Int] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            guard !lower.isEmpty,
                  !isNoise(lower),
                  extractPrice(from: trimmed) != nil,
                  matchSummaryType(lower) == nil else { continue }

            if let regex = leadingNumRegex,
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed),
               let num = Int(trimmed[range]) {
                sequence.append(num)
            }
        }

        guard sequence.count >= 3 else { return false }
        // Check consecutive: sorted list must equal [first, first+1, first+2, ...]
        let sorted = sequence.sorted()
        let expected = Array(sorted[0]..<(sorted[0] + sorted.count))
        return sorted == expected && sorted[0] <= 2
    }

    private static func extractQuantity(from line: String) -> Int {
        let patterns = [
            #"^(\d+)\s*[xX]\s"#,
            #"^(\d{1,2})\s+"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line),
               let qty = Int(line[range]), qty > 0, qty < 100 {
                return qty
            }
        }
        return 1
    }

    private static func cleanItemName(_ line: String) -> String {
        var name = line

        // Always strip leading numbers from the name — whether they're bullets
        // (numbered list) or quantities (e.g. "2 Cavatelli"). The quantity value
        // is captured separately by extractQuantity before this is called.
        let removePatterns: [String] = [
            #"\$\s*\d+\.\d{2}"#,
            #"\d+\.\d{2}"#,
            #"^\d+\s*[xX]\s+"#,
            #"^\d{1,2}\s+"#,
            #"^\d+\.\s*"#,
            #"\$"#,
        ]
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                name = regex.stringByReplacingMatches(
                    in: name,
                    range: NSRange(name.startIndex..., in: name),
                    withTemplate: ""
                )
            }
        }

        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let trailingJunk = CharacterSet(charactersIn: ".:;,*#-_=+")
        name = name.trimmingCharacters(in: trailingJunk)
        name = name.trimmingCharacters(in: .whitespaces)

        name = balanceParentheses(name)

        return name
    }

    private static func balanceParentheses(_ text: String) -> String {
        let openCount = text.filter { $0 == "(" }.count
        let closeCount = text.filter { $0 == ")" }.count

        if openCount > closeCount {
            return text + String(repeating: ")", count: openCount - closeCount)
        }
        return text
    }

    private static let headerNoisePatterns: [String] = [
        #"\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}"#,
        #"\d{1,2}:\d{2}"#,
        #"opened:"#, #"order:"#, #"check:"#, #"table"#, #"server"#, #"guest"#,
        #"dine.?in"#, #"take.?out"#, #"delivery"#,
        #"\d{3}[.\-\s]?\d{3}[.\-\s]?\d{4}"#,
        #"www\."#, #"\.com"#, #"http"#,
        #"\d{5}"#,
        #"receipt"#, #"invoice"#,
    ]

    private static func extractRestaurantName(from lines: [String]) -> String? {
        let candidateLines = Array(lines.prefix(10))

        // Collect consecutive valid name lines from the top of the receipt,
        // then join them. Handles multi-line names like "The / BLACK / CAT".
        var nameParts: [String] = []
        var foundFirst = false

        for line in candidateLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            guard !trimmed.isEmpty else { continue }

            // Stop collecting once we've started and hit an address / metadata line
            if foundFirst && looksLikeAddressOrMeta(trimmed) { break }

            guard trimmed.count >= 2 else { continue }

            if extractPrice(from: trimmed) != nil { continue }

            var isHeaderNoise = false
            for pattern in headerNoisePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                    isHeaderNoise = true
                    break
                }
            }
            if isHeaderNoise {
                // If we've already collected name parts, stop here
                if foundFirst { break }
                continue
            }

            let letterCount = trimmed.filter(\.isLetter).count
            let totalCount = trimmed.filter { !$0.isWhitespace }.count
            guard totalCount > 0, Double(letterCount) / Double(totalCount) > 0.55 else {
                if foundFirst { break }
                continue
            }

            let cleaned = trimmed
                .trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'-")))
                .trimmingCharacters(in: .whitespaces)

            guard cleaned.count >= 2 else { continue }

            nameParts.append(cleaned)
            foundFirst = true

            // Stop accumulating after 4 parts — names shouldn't be longer
            if nameParts.count >= 4 { break }
        }

        guard !nameParts.isEmpty else { return nil }

        // Join parts: if each part is short (≤ 12 chars) they're likely split lines of one name
        let joined: String
        if nameParts.count > 1 && nameParts.allSatisfy({ $0.count <= 16 }) {
            joined = nameParts.joined(separator: " ")
        } else {
            joined = nameParts[0]
        }

        return joined.count >= 2 ? joined : nil
    }

    private static func looksLikeAddressOrMeta(_ line: String) -> Bool {
        // Lines that signal we've left the restaurant name zone
        let addressPatterns = [
            #"\d{3,}"#,          // 3+ digit run (street number, zip, phone)
            #"@"#,               // social handle / email
            #"www\."#,           // website
            #"\.com"#,
            #"server"#,
            #"check\s*#"#,
            #"table"#,
            #"ordered"#,
        ]
        let lower = line.lowercased()
        for pattern in addressPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                return true
            }
        }
        return false
    }

    private static func matchSummaryType(_ line: String) -> SummaryType? {
        for (pattern, type) in summaryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                return type
            }
        }
        return nil
    }

    private static func isNoise(_ line: String) -> Bool {
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                return true
            }
        }

        let letters = line.filter(\.isLetter).count
        if letters == 0 { return true }

        return false
    }
}
