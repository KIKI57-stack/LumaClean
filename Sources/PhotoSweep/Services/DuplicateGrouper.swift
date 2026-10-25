import Foundation

struct UnionFind {
    private var parent: [Int]

    init(count: Int) {
        parent = Array(0..<count)
    }

    mutating func find(_ value: Int) -> Int {
        var current = value
        while parent[current] != current {
            parent[current] = parent[parent[current]]
            current = parent[current]
        }
        return current
    }

    mutating func union(_ a: Int, _ b: Int) {
        let rootA = find(a)
        let rootB = find(b)
        if rootA != rootB { parent[rootB] = rootA }
    }
}

enum DuplicateGrouper {
    /// 把 64 bit 哈希切成 8 个字节做多重索引。
    /// 汉明距离 <= 7 时，必然至少有一个字节完全相同，所以只比对同桶候选即可，
    /// 避免全库两两比较。
    static func groups(from items: [MediaItem], maxDistance: Int) -> [[MediaItem]] {
        let hashed = items.filter { $0.hash != nil }
        guard hashed.count > 1 else { return [] }

        var buckets = [[UInt64: [Int]]](repeating: [:], count: 8)
        for (index, item) in hashed.enumerated() {
            guard let hash = item.hash else { continue }
            for position in 0..<8 {
                let key = (hash >> UInt64(position * 8)) & 0xFF
                buckets[position][key, default: []].append(index)
            }
        }

        var unionFind = UnionFind(count: hashed.count)

        for (index, item) in hashed.enumerated() {
            guard let hash = item.hash else { continue }

            var candidates = Set<Int>()
            for position in 0..<8 {
                let key = (hash >> UInt64(position * 8)) & 0xFF
                if let list = buckets[position][key] {
                    for candidate in list where candidate != index {
                        candidates.insert(candidate)
                    }
                }
            }

            if candidates.count > 600 {
                candidates = Set(candidates.prefix(600))
            }

            for candidate in candidates {
                guard let other = hashed[candidate].hash else { continue }
                if ImageAnalyzer.hamming(hash, other) <= maxDistance {
                    unionFind.union(index, candidate)
                }
            }
        }

        var collected: [Int: [Int]] = [:]
        for index in 0..<hashed.count {
            collected[unionFind.find(index), default: []].append(index)
        }

        return collected.values
            .filter { $0.count >= 2 }
            .map { $0.map { hashed[$0] } }
    }

    static func maxPairwiseDistance(_ items: [MediaItem]) -> Int {
        guard items.count > 1 else { return 0 }
        var maxDistance = 0
        for i in 0..<items.count {
            guard let hashA = items[i].hash else { continue }
            for j in (i + 1)..<items.count {
                guard let hashB = items[j].hash else { continue }
                maxDistance = max(maxDistance, ImageAnalyzer.hamming(hashA, hashB))
            }
        }
        return maxDistance
    }
}
