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
    
    func insert(_ word: String, frequency: Int = 1) {
        let characters = Array(word).map(String.init)
        var current = self
        
        for char in characters {
            if current.children[char] == nil {
                current.children[char] = TrieNode()
            }
            current = current.children[char]!
        }
        
        current.isEndOfWord = true
        current.frequency = frequency
        current.word = word
    }
    
    func searchPrefix(_ prefix: String) -> TrieNode? {
        let characters = Array(prefix).map(String.init)
        var current = self
        
        for char in characters {
            guard let nextNode = current.children[char] else {
                return nil
            }
            current = nextNode
        }
        
        return current
    }
    
    func contains(_ word: String) -> Bool {
        var current = self
        for char in word {
            guard let child = current.children[String(char)] else {
                return false
            }
            current = child
        }
        return current.isEndOfWord
    }
    
    func getAllWords(limit: Int = 10) -> [(word: String, frequency: Int)] {
        // Collect all words in the subtree, then return the top-N by frequency.
        // This ensures we don't prematurely stop and miss higher-frequency words
        // located deeper in the trie.
        var collected: [(String, Int)] = []

        func dfs(_ node: TrieNode) {
            if node.isEndOfWord, let word = node.word {
                collected.append((word, node.frequency))
            }

            // Explore higher-frequency subtrees first to improve early results
            let sortedChildren = node.children.sorted {
                $0.value.getMaxFrequency() > $1.value.getMaxFrequency()
            }

            for (_, childNode) in sortedChildren {
                dfs(childNode)
            }
        }

        dfs(self)
        if collected.count <= limit { return collected.sorted { $0.1 > $1.1 } }
        // Partial sort by frequency for efficiency when many items
        collected.sort { $0.1 > $1.1 }
        return Array(collected.prefix(limit))
    }
    
    private func getMaxFrequency() -> Int {
        var maxFreq = isEndOfWord ? frequency : 0
        for (_, child) in children {
            maxFreq = max(maxFreq, child.getMaxFrequency())
        }
        return maxFreq
    }
}
