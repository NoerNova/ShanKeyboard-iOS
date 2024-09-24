//
//  About.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 25/9/2567 BE.
//

import SwiftUI

struct AboutScreen: View {
    var body: some View {
            VStack {
                Image(systemName: "keyboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                Text("Panglong Keyboard")
                    .padding()
                    .font(.system(size: 32, weight: .medium, design: .default))
                Text("Version: 0.5")
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    UIApplication.shared.open(URL(string: "https://noernova.com")!)
                }
                label: {
                    Text("Contact Me")
                }
                Spacer()
            }
    }
}

#Preview {
    AboutScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
