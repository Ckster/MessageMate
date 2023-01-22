//
//  ContentView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        SignInView().environmentObject(self.session)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
