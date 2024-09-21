//
//  ContentView.swift
//  Panglong_iKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import SwiftUI
import SwiftData

struct Home: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State 
    private var text: String = ""
    
    @State
    private var textEmail: String = ""
    
    @State
    private var textURL: String = ""
    
    var body: some View {
        NavigationView {
            Panglong_iKeyboardApp.HomeScreen
        }
    }
    
}

#Preview {
    Home()
        .modelContainer(for: Item.self, inMemory: true)
}
