//
//  ContentView.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 18/9/2567 BE.
//

import SwiftUI
import SwiftData
import ShanKeyboardShared

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var text: String = ""
    @State private var presentedLicense = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedLayout: KeyboardInputSetLayout = SharedUserDefaults.shared.keyboardLayout
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                // iPhone layout
                NavigationView {
                    pageContent
                }
            } else {
                // iPad layout
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        pageContent
                            .frame(width: min(geometry.size.width * 0.7, 600))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

extension HomeScreen {
    private var pageContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Section
                VStack(spacing: 8) {
                    Text("Shan Keyboard")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Open Source, Privacy Focused, Free to use.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Text Input Demo Section
                ModernCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Try it out")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedLayout.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        if !text.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Output:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Text(text)
                                    .font(.custom("Shan", size: 18))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        TextField("Type something...", text: $text)
                            .font(.system(size: 16))
                            .padding(16)
                            .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(text.isEmpty ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Setup Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Setup")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        NavigationLink(destination: AddKeyboardScreen()) {
                            SettingRow(
                                icon: "keyboard",
                                title: "Add Keyboard",
                                subtitle: "Enable the Shan keyboard in settings"
                            )
                        }
                        
                        NavigationLink(destination: KeyboardLayoutPreferencesView()) {
                            SettingRow(
                                icon: "textformat.abc",
                                title: "Layout Preferences",
                                subtitle: "Select preferred keyboard layout"
                            )
                        }
                    }
                }
                
                // Source Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Open Source")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        Button {
                            UIApplication.shared.open(URL(string: "https://github.com/NoerNova/ShanKeyboard-iOS")!)
                        } label: {
                            SettingRow(
                                icon: "chevron.left.forwardslash.chevron.right",
                                title: "Source Code",
                                subtitle: "View on GitHub"
                            )
                        }
                        
                        Button {
                            self.presentedLicense.toggle()
                        } label: {
                            SettingRow(
                                icon: "doc.text",
                                title: "License",
                                subtitle: "MIT License"
                            )
                        }
                    }
                }
                
                // About Section
                ModernCard {
                    VStack(spacing: 16) {
                        NavigationLink(destination: AboutScreen()) {
                            HStack(spacing: 16) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("About")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Learn more about this app")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                            .opacity(0.5)
                        
                        HStack {
                            Text("Version")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1.0")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Footer
                VStack(spacing: 8) {
                    Text("Copyright © 2025 NoerNova")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $presentedLicense) {
            LicenseScreen()
        }
        .onAppear() {
            selectedLayout = SharedUserDefaults.shared.keyboardLayout
        }
    }
}

struct ModernCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
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
