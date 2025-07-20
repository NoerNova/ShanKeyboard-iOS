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
    
    func getAllWords(limit: Int = 10) -> [(word: String, frequency: Int)] {
        var results: [(String, Int)] = []
        
        func dfs(_ node: TrieNode) {
            if results.count >= limit { return }
            
            if node.isEndOfWord, let word = node.word {
                results.append((word, node.frequency))
            }
            
            // Sort children by frequency for better suggestions
            let sortedChildren = node.children.sorted {
                $0.value.getMaxFrequency() > $1.value.getMaxFrequency()
            }
            
            for (_, childNode) in sortedChildren {
                if results.count >= limit { break }
                dfs(childNode)
            }
        }
        
        dfs(self)
        return results.sorted { $0.1 > $1.1 }
    }
    
    private func getMaxFrequency() -> Int {
        var maxFreq = isEndOfWord ? frequency : 0
        for (_, child) in children {
            maxFreq = max(maxFreq, child.getMaxFrequency())
        }
        return maxFreq
    }
}

