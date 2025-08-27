//
//  About.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 25/9/2567 BE.
//

import SwiftUI

struct AboutScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "keyboard")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Shan Keyboard")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                        
                        Text("Version: 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Making Shan language typing simple on iOS")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                Divider()
                
                // Project Overview
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "About This Project", icon: "info.circle")
                    
                    Text("This project, which is based on the now-archived PanglongKeyboard-iOS, aims to make customizing the Shan language keyboard layout for iOS much easier **until native support from Apple becomes available.**")
                        .font(.body)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                // Project Goals Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Project Goal", icon: "target")
                    
                    Text("The goal of this project is to replicate the native iOS keyboard layout experience for the Shan language. It prioritizes simplicity:")
                        .font(.body)
                        .lineSpacing(2)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(text: "No fancy themes (though they could be added later)")
                        BulletPoint(text: "No cluttered settings buttons (which can also be added later)")
                        BulletPoint(text: "No privacy concerns—just type!").fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                // Technical Details
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(title: "Technical Implementation", icon: "gearshape.2")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("KeyboardKit")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("This project is based on KeyboardKit, which does not yet support the Shan locale. To address this, I created a custom fork: [KeyboardKit](https://github.com/NoerNova/KeyboardKit). This fork adds some locale information for Shan, although it is not perfect yet. I hope to submit a pull request to the main repository soon.")
                            .font(.body)
                            .lineSpacing(2)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ISEmojiView")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Since the free version of KeyboardKit doesn't support an emoji keyboard, I integrated [ISEmojiView](https://github.com/NoerNova/ISEmojiView) (custom fork), a SwiftUI package, to serve as a wrapper for emoji input. It works as intended.")
                            .font(.body)
                            .lineSpacing(2)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Text Autocomplete")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("This project also implements a basic text autocomplete feature, using a word list from the ShanNLP project. Word frequency analysis was performed using data from the [shannews.org](https://shannews.org/) domain and [Shan Wikipedia](https://shn.wikipedia.org/). The word list isn't fully optimized for daily typing yet, but I hope to expand it when I have more time and energy.")
                            .font(.body)
                            .lineSpacing(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                // Publishing
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Publishing", icon: "app.badge")
                    
                    Text("This project is being published to the Apple App Store, sponsored by **SHAN (Shan Herald Agency for News).**")
                        .font(.body)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                // Contact
                VStack(spacing: 16) {
                    Text("Get in Touch")
                        .font(.headline)
                    
                    Button(action: {
                        UIApplication.shared.open(URL(string: "https://noernova.com")!)
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("Contact Me")
                        }
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .cornerRadius(25)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper Views
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
                .font(.body)
                .fontWeight(.bold)
            Text(text)
                .font(.body)
                .lineSpacing(2)
        }
    }
}

#Preview {
    NavigationView {
        AboutScreen()
    }
    .modelContainer(for: Item.self, inMemory: true)
}
