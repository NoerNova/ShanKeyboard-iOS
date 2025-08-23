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
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedLayout: KeyboardInputSetLayout = SharedUserDefaults.shared.keyboardLayout
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Hero Section
                    heroSection
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    
                    // Try It Section
                    sectionContainer {
                        tryItSection
                    }
                    
                    // Quick Actions
                    sectionContainer {
                        quickActionsSection
                    }
                    
                    // Resources
                    sectionContainer {
                        resourcesSection
                    }
                    
                    // Footer
                    footerSection
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, horizontalPadding)
            }
            .background(backgroundColor)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $presentedLicense) {
            LicenseScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            selectedLayout = SharedUserDefaults.shared.keyboardLayout
        }
    }
    
    // MARK: - Layout Properties
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 20 : max(40, (UIScreen.main.bounds.width - 800) / 2)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color.white
    }
    
    // MARK: - Sections
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // App Icon/Logo placeholder
            Circle()
                .fill(LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "keyboard")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
            
            VStack(spacing: 8) {
                Text("Shan Keyboard")
                    .font(.system(size: horizontalSizeClass == .compact ? 32 : 40,
                                  weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Open source, privacy focused, free to use")
                    .font(.system(size: horizontalSizeClass == .compact ? 16 : 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    private var tryItSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Try it out", icon: "keyboard")
            
            VStack(spacing: 16) {
                // Layout selector
                HStack {
                    Text("Layout:")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(selectedLayout.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                
                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Type something in Shan...", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: 17))
                        .padding(16)
                        .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(text.isEmpty ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Output display
                if !text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        
                        Text(text)
                            .font(.custom("Shan", size: 20))
                            .foregroundColor(.primary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Setup", icon: "gearshape.fill")
            
            VStack(spacing: 12) {
                NavigationLink(destination: AddKeyboardScreen()) {
                    ActionCard(
                        icon: "keyboard",
                        title: "Add Keyboard",
                        subtitle: "Enable Shan keyboard in iOS settings",
                        accent: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: KeyboardLayoutPreferencesView()) {
                    ActionCard(
                        icon: "textformat.abc",
                        title: "Layout Preferences",
                        subtitle: "Choose your preferred keyboard layout",
                        accent: .green
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Resources", icon: "book.fill")
            
            VStack(spacing: 12) {
                Button {
                    UIApplication.shared.open(URL(string: "https://github.com/NoerNova/ShanKeyboard-iOS")!)
                } label: {
                    ActionCard(
                        icon: "chevron.left.forwardslash.chevron.right",
                        title: "Source Code",
                        subtitle: "View project on GitHub",
                        accent: .orange,
                        hasExternalLink: true
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    presentedLicense.toggle()
                } label: {
                    ActionCard(
                        icon: "doc.text.fill",
                        title: "License",
                        subtitle: "MIT License - Free to use and modify",
                        accent: .purple
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: AboutScreen()) {
                    ActionCard(
                        icon: "info.circle.fill",
                        title: "About",
                        subtitle: "Learn more about this project",
                        accent: .indigo
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Divider()
                .opacity(0.5)
                .padding(.vertical, 20)
            
            HStack {
                Text("Version 1.0")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("© 2025 NoerNova")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 32)
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Action Card Component

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let hasExternalLink: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(icon: String, title: String, subtitle: String, accent: Color, hasExternalLink: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.hasExternalLink = hasExternalLink
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Arrow or external link indicator
            Image(systemName: hasExternalLink ? "arrow.up.right" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview {
    HomeScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
