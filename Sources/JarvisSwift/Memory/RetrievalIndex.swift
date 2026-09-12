import Foundation

/// 检索索引
struct RetrievalIndex {
    private var tokenIndex: [String: Set<UUID>] = [:]
    private var ngramIndex: [String: Set<UUID>] = [:]
    private var entries: [UUID: IndexedMemory] = [:]

    mutating func add(_ entry: IndexedMemory) {
        entries[entry.id] = entry
        for token in entry.tokens {
            tokenIndex[token, default: []].insert(entry.id)
        }
        for ngram in entry.ngrams {
            ngramIndex[ngram, default: []].insert(entry.id)
        }
    }

    mutating func remove(_ id: UUID) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        for token in entry.tokens {
            tokenIndex[token]?.remove(id)
            if tokenIndex[token]?.isEmpty == true {
                tokenIndex[token] = nil
            }
        }
        for ngram in entry.ngrams {
            ngramIndex[ngram]?.remove(id)
            if ngramIndex[ngram]?.isEmpty == true {
                ngramIndex[ngram] = nil
            }
        }
    }

    func retrieve(query: String, limit: Int = 5, from indexedItems: [IndexedMemory]) -> [RetrievalResult] {
        // If no query, return most recent entries
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sorted = indexedItems.sorted { $0.id.uuidString > $1.id.uuidString } // not ideal but works
            return sorted.prefix(limit).map { item in
                RetrievalResult(
                    id: item.id,
                    content: item.content,
                    score: 1.0,
                    source: item.metadata
                )
            }
        }

        // Compute query tokens and ngrams
        let queryLower = query.lowercased()
        let queryTokens = Set(tokenize(queryLower))
        let queryNGrams = Set(ngrams(from: queryLower, length: 3))

        // Score each candidate
        var scored: [(id: UUID, score: Double, metadata: RetrievalResult.MemorySource)] = []
        for item in indexedItems {
            var score: Double = 0.0

            // Token overlap
            let tokenOverlap = Double(item.tokens.intersection(queryTokens).count)
            if !item.tokens.isEmpty {
                score += tokenOverlap / Double(max(item.tokens.count, queryTokens.count))
            }

            // Ngram overlap
            let ngramOverlap = Double(item.ngrams.intersection(queryNGrams).count)
            if !item.ngrams.isEmpty {
                score += ngramOverlap / Double(max(item.ngrams.count, queryNGrams.count))
            }

            // Substring bonus (exact phrase)
            if item.content.lowercased().contains(queryLower) {
                score += 1.0
            }

            // Boost by importance if available (not in IndexedMemory, need to pass?)
            // We'll ignore for now; importance is in MemoryEntry which we don't have here.
            // Could extend IndexedMemory to hold importance.

            if score > 0 {
                scored.append((id: item.id, score: score, metadata: item.metadata))
            }
        }

        // Sort by score descending
        let sorted = scored.sorted { $0.score > $1.score }
        return sorted.prefix(limit).map { tuple in
            RetrievalResult(
                id: tuple.id,
                content: entries[tuple.id]?.content ?? "",
                score: tuple.score,
                source: tuple.metadata
            )
        }
    }

    func rebuild(from items: [IndexedMemory]) {
        tokenIndex.removeAll()
        ngramIndex.removeAll()
        entries.removeAll()
        for item in items {
            add(item)
        }
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        let regex = try? NSRegularExpression(pattern: "[\\p{Alphabetic}]+|\\p{Nd}+")
        let range = NSRange(location: 0, length: text.utf16.count)
        regex?.enumerateMatches(in: text, range: range) { result, _, _ in
            guard let result = result else { return }
            let nsRange = result.range
            if let swiftRange = Range(nsRange, in: text) {
                tokens.append(String(text[swiftRange]).lowercased())
            }
        }
        return tokens
    }

    private static func ngrams(from text: String, length: Int) -> [String] {
        guard text.count >= length else { return [] }
        var result: [String] = []
        let chars = Array(text)
        for i in 0...(chars.count - length) {
            result.append(String(chars[i..<i + length]))
        }
        return result
    }
}