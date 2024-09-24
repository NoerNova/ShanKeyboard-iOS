//
//  AddKeyboardScreen.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 25/9/2567 BE.
//

import SwiftUI

struct AddKeyboardScreen: View {
    
    @State private var promptToOpenSetting = false
    
    var body: some View {
            VStack {
                Image("setupShanKeyboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                Button {
                    self.promptToOpenSetting.toggle()
                } label: {
                    Text("Open Settings")
                        .frame(width: 280, height: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .cornerRadius(10)
                }
                .alert(isPresented: $promptToOpenSetting) {
                           Alert(
                               title: Text("Panglong Keyboard"),
                               message: Text("သႂ်ႇလွၵ်းမိုဝ်း"),
                               primaryButton: .default(Text("Open")) {
                                   openSetting()
                               },
                            secondaryButton: .cancel()
                           )
                       }
            }
            .navigationBarTitle("Setup keyboard")
    }
}

func openSetting() {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
           return
       }

       if UIApplication.shared.canOpenURL(settingsUrl) {
           UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
       }
}

#Preview {
    AddKeyboardScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
