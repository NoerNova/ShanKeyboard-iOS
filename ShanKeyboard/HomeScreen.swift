//
//  ContentView.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var text: String = ""
    @State private var presentedLicense = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Test")) {
                        VStack() {
                            VStack() {
                                Text(text)
                                    .foregroundStyle(Color.primary)
                                    .font(.custom("Shan", size: 14))
                                    .foregroundStyle(.gray)
                            }
                            TextField(
                                "Type something...", text: $text
                            )
                            .frame(height: 48)
                            .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(lineWidth: 1.0)
                            )
                        }
                    }
                    Section(header: Text("SETUP")) {
                        NavigationLink(
                            destination: AddKeyboardScreen(),
                            label: {
                                SettingButton(useSystemImage: true, buttonImage: "keyboard", buttonTitle: "Add Keyboard", isNavigationButton: true)
                            })
                    }
                    Section(header: Text("SOURCE")) {
                        Button {
                            UIApplication.shared.open(URL(string: "https://github.com/NoerNova/ShanKeyboard-iOS")!)
                        }
                        label: {
                            NavigationLink(
                                destination: Text("Destination"),
                                label: {
                                    SettingButton(useSystemImage: false, buttonImage: "GitHub", buttonTitle: "Source Code", isNavigationButton: true)
                                }
                            )
                        }
                        Button {
                            self.presentedLicense.toggle()
                        }
                        label: {
                            NavigationLink(
                                destination: Text("MIT License, Copyright (c) 2024 NoerNova"),
                                label: {
                                    SettingButton(useSystemImage: false, buttonImage: "MIT", buttonTitle: "License", isNavigationButton: true)
                                })
                        }
                    }
                    Section(header: Text("About")) {
                        NavigationLink(
                            destination: AboutScreen(),
                            label: {
                                SettingButton(useSystemImage: true, buttonImage: "info.circle.fill", buttonTitle: "About", isNavigationButton: true)
                            })
                        HStack {
                            Text("Version")
                            
                                .foregroundColor(.gray)
                            Spacer()
                            Text("0.5")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 60)
                    }
                    Text("Copyright © 2024 NoerNova")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.gray)
                }
                
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Shan Keyboard")
            .sheet(isPresented: $presentedLicense) {
                LicenseScreen()
            }
        }
    }
}

struct SettingButton: View {
    
    var useSystemImage: Bool
    var buttonImage: String
    var buttonTitle: String
    var isNavigationButton: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        HStack {
            useSystemImage ?
            Image(systemName: buttonImage)
                .resizable()
                .padding()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            :
            Image(buttonImage)
                .resizable()
                .padding()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            Text(buttonTitle)
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
        }
        
    }
}

#Preview {
    HomeScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
