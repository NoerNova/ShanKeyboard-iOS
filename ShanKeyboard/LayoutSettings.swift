//
//  LayoutSettings.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 28/7/2568 BE.
//

import SwiftUI
import ShanKeyboardShared

struct KeyboardLayoutPreferencesView: View {
    @State private var selectedLayout: KeyboardInputSetLayout = SharedUserDefaults.shared.keyboardLayout
    
    var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Select Keyboard Layout")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    Text("Choose your preferred keyboard layout for the custom keyboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(KeyboardInputSetLayout.allCases, id: \.self) { layout in
                            LayoutSelectionCard(
                                layout: layout,
                                isSelected: selectedLayout == layout
                            ) {
                                selectedLayout = layout
                                SharedUserDefaults.shared.keyboardLayout = layout
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Current selection display
                    VStack(spacing: 8) {
                        Text("Current Selection:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(selectedLayout.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom)
                    
                    // Important note for users
                    VStack(spacing: 4) {
                        Text("Note:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("Changes will be applied to your custom keyboard immediately")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .navigationTitle("Keyboard Settings")
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                // Refresh from shared defaults when view appears
                selectedLayout = SharedUserDefaults.shared.keyboardLayout
            }
        }
}

struct LayoutSelectionCard: View {
    let layout: KeyboardInputSetLayout
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(layout.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(layout.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview
struct KeyboardPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardLayoutPreferencesView()
    }
}
