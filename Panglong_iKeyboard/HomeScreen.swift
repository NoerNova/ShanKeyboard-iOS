//
//  ContentView.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var text: String = ""
    
    var body: some View {
        VStack() {
                Text(text)
                    .foregroundStyle(Color.primary)
                TextField(
                    "Typing...", text: $text
                )
                .frame(height: 48)
                .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 1.0)
                )
        }
        .frame(width: 300, height: 300)
    }
    
}

#Preview {
    HomeScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
