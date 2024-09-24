//
//  LicenseScreen.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 25/9/2567 BE.
//

import SwiftUI

struct LicenseScreen: View {
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View{
        NavigationView {
            ScrollView {
                VStack {
                    Text(loadLicenseFile(filename: "LICENSE")).frame(maxWidth: .infinity)
                }
            }.padding()
            
            .navigationBarTitle("License")
            .navigationBarItems(trailing: Button("Dismiss"){
                presentationMode.wrappedValue.dismiss()
            })
        }
        
    }
}

func loadLicenseFile(filename: String ) -> String  {
    
    let url = Bundle.main.url(forResource: filename, withExtension: "txt")!
    let data = try! Data(contentsOf: url)
    let string = String(data: data, encoding: .utf8)!
    return string
}

#Preview {
    LicenseScreen()
        .modelContainer(for: Item.self, inMemory: true)
}
