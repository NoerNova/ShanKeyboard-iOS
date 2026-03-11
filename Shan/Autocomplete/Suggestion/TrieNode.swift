//
//  TrieNode.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 17/7/2568 BE.
//

class TrieNode {
    var children: [String: TrieNode] = [:]
    var isEndOfWord: Bool = false
    var frequency: Int = 0
    var word: String?

    /// Convert a string to an array of Unicode scalar strings for consistent trie traversal.
    /// Using Unicode scalars instead of grapheme clusters ensures that incomplete Shan words
    /// (e.g. "ၵုမ") can match prefixes of complete words (e.g. "ၵုမ်"),
    /// since combining characters like ် are stored as separate trie nodes.
    private static func scalarKeys(_ text: String) -> [String] {
        text.unicodeScalars.map { String($0) }
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
        current.word = word
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

    private func removeHelper(_ chars: [String], index: Int) -> Bool {
        if index == chars.count {
            guard isEndOfWord else { return false }
            isEndOfWord = false
            word = nil
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

    func getAllWords(limit: Int = 10) -> [(word: String, frequency: Int)] {
        var collected: [(String, Int)] = []
        collected.reserveCapacity(limit * 2)

        func dfs(_ node: TrieNode) {
            if node.isEndOfWord, let word = node.word {
                collected.append((word, node.frequency))
            }
            for (_, childNode) in node.children {
                dfs(childNode)
            }
        }

        dfs(self)
        if collected.count <= limit { return collected.sorted { $0.1 > $1.1 } }
        collected.sort { $0.1 > $1.1 }
        return Array(collected.prefix(limit))
    }
}
