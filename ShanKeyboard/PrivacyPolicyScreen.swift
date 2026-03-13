//
//  PrivacyPolicyScreen.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 13/3/2569 BE.
//

import SwiftUI

struct PrivacyPolicyScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.teal)

                    Text("Privacy Policy")
                        .font(.system(size: 28, weight: .bold, design: .default))

                    Text("Your privacy is our priority")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                Divider()

                // No Data Collection
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "No Data Collection", icon: "xmark.shield")

                    Text("Shan Keyboard does not collect, transmit, or share any personal data. The keyboard operates entirely offline with no network access.")
                        .font(.body)
                        .lineSpacing(2)
                }
                .padding(.horizontal)

                Divider()

                // What is stored
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "What Is Stored On-Device", icon: "iphone")

                    Text("To improve your typing experience, the following data is stored locally on your device only:")
                        .font(.body)
                        .lineSpacing(2)

                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(text: "Learned words — words you type frequently")
                        BulletPoint(text: "Syllable and character frequency — to rank suggestions")
                        BulletPoint(text: "Word patterns — to predict next-word suggestions")
                        BulletPoint(text: "Keyboard layout preference")
                    }

                    Text("This data never leaves your device and is not accessible to any external service.")
                        .font(.body)
                        .lineSpacing(2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)

                Divider()

                // What is NOT collected
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "What We Do NOT Collect", icon: "hand.raised")

                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(text: "No keystrokes or typing content sent anywhere")
                        BulletPoint(text: "No analytics or usage tracking")
                        BulletPoint(text: "No clipboard access")
                        BulletPoint(text: "No network connections of any kind")
                        BulletPoint(text: "No advertising identifiers")
                        BulletPoint(text: "No third-party SDKs that collect data")
                    }
                }
                .padding(.horizontal)

                Divider()

                // Sensitive fields
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Sensitive Text Fields", icon: "key")

                    Text("When you type in password fields, credit card fields, or one-time code fields, the keyboard automatically disables autocomplete suggestions and does not learn or record any input.")
                        .font(.body)
                        .lineSpacing(2)
                }
                .padding(.horizontal)

                Divider()

                // Data control
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Your Data, Your Control", icon: "slider.horizontal.3")

                    Text("You can clear all learned data at any time from the app's home screen using the \"Clear Learned Data\" option. This permanently removes all learned words, frequency data, and typing patterns.")
                        .font(.body)
                        .lineSpacing(2)
                }
                .padding(.horizontal)

                Divider()

                // Open source
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Open Source Transparency", icon: "chevron.left.forwardslash.chevron.right")

                    Text("Shan Keyboard is open source. You can inspect the full source code to verify these privacy claims.")
                        .font(.body)
                        .lineSpacing(2)

                    Button(action: {
                        UIApplication.shared.open(URL(string: "https://github.com/NoerNova/ShanKeyboard-iOS")!)
                    }) {
                        HStack(spacing: 10) {
                            Image("GitHub")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                            Text("View Source Code on GitHub")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyScreen()
    }
}
