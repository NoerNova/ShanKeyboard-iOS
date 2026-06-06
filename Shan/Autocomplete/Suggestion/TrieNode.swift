//
//  TrieNode.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 17/7/2568 BE.
//

class TrieNode {
    // Keyed by Unicode.Scalar rather than String: avoids a heap String allocation per
    // edge, and there are far more edges than words. Halving this footprint is the
    // dominant steady-state memory win for the three resident tries.
    var children: [Unicode.Scalar: TrieNode] = [:]
    var isEndOfWord: Bool = false
    var frequency: Int = 0

    /// Convert a string to an array of Unicode scalars for consistent trie traversal.
    /// Using Unicode scalars instead of grapheme clusters ensures that incomplete Shan words
    /// (e.g. "ၵုမ") can match prefixes of complete words (e.g. "ၵုမ်"),
    /// since combining characters like ် are stored as separate trie nodes.
    private static func scalarKeys(_ text: String) -> [Unicode.Scalar] {
        Array(text.unicodeScalars)
    }

    func insert(_ word: String, frequency: Int = 1) {
        let characters = TrieNode.scalarKeys(word)
        var current = self

        for char in characters {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }

        current.isEndOfWord = true
        current.frequency = max(current.frequency, frequency)
    }

    func searchPrefix(_ prefix: String) -> TrieNode? {
        let characters = TrieNode.scalarKeys(prefix)
        var current = self

        for char in characters {
            guard let nextNode = current.children[char] else {
                return nil
            }
            current = nextNode
        }

        return current
    }

    /// Fast prefix existence check - O(prefix length)
    func hasPrefix(_ prefix: String) -> Bool {
        return searchPrefix(prefix) != nil
    }

    func contains(_ word: String) -> Bool {
        let characters = TrieNode.scalarKeys(word)
        var current = self
        for char in characters {
            guard let child = current.children[char] else {
                return false
            }
            current = child
        }
        return current.isEndOfWord
    }

    /// Remove a word from the trie. Returns true if the word was found and removed.
    @discardableResult
    func remove(_ word: String) -> Bool {
        let characters = TrieNode.scalarKeys(word)
        return removeHelper(characters, index: 0)
    }

    private func removeHelper(_ chars: [Unicode.Scalar], index: Int) -> Bool {
        if index == chars.count {
            guard isEndOfWord else { return false }
            isEndOfWord = false
            frequency = 0
            return children.isEmpty
        }
        guard let child = children[chars[index]] else { return false }
        let shouldDelete = child.removeHelper(chars, index: index + 1)
        if shouldDelete {
            children.removeValue(forKey: chars[index])
            return !isEndOfWord && children.isEmpty
        }
        return false
    }

    /// Collects words in the subtree rooted at this node.
    /// Words are reconstructed from the traversal path rather than stored per-node
    /// (a stored `word` String at every terminal duplicated the entire dictionary in RAM).
    /// `prefix` is the string that located this node, so emitted words are complete.
    func getAllWords(prefix: String = "", limit: Int = 10) -> [(word: String, frequency: Int)] {
        var collected: [(String, Int)] = []
        collected.reserveCapacity(limit * 2)

        var path = Array(prefix.unicodeScalars)

        func dfs(_ node: TrieNode) {
            if node.isEndOfWord {
                collected.append((String(String.UnicodeScalarView(path)), node.frequency))
            }
            for (scalar, childNode) in node.children {
                path.append(scalar)
                dfs(childNode)
                path.removeLast()
            }
        }

        dfs(self)
        if collected.count <= limit { return collected.sorted { $0.1 > $1.1 } }
        collected.sort { $0.1 > $1.1 }
        return Array(collected.prefix(limit))
    }
}
