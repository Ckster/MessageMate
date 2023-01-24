//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI

struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        Text("Inbox")
    }
}

struct InboxView_Previews: PreviewProvider {
    static var previews: some View {
        InboxView()
    }
}
