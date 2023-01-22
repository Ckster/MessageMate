//
//  MessageMateApp.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import Foundation
import SwiftUI

@main
struct MessageMateApp: App {
    @UIApplicationDelegateAdaptor var delegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(SessionStore())
        }
    }
}
