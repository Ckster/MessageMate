//
//  NoProfilePictureView.swift
//  Interactify
//
//  Created by Erick Verleye on 4/27/23.
//

import SwiftUI

struct InitialsView: View {
    var firstName: String
    var lastName: String? = nil
    
    init(name: String) {
        let nameSplit = name.split(separator: " ")
        self.firstName = String(nameSplit[0])
        if nameSplit.count > 1 {
            self.lastName = String(nameSplit[1])
        }
    }
    
    var body: some View {
        
        let initials = String(firstName.uppercased().prefix(1) + (lastName?.uppercased().prefix(1) ?? ""))
        
        ZStack {
            Circle()
                .fill(Color("Purple"))
            Text(initials)
                .foregroundColor(.white)
                .font(.system(size: 30))
        }
        .frame(width: 80, height: 80)
    }
}
