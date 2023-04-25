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
    @StateObject private var messagingDataController = MessagingDataController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SceneDelegate.session)
                .environment(\.managedObjectContext, messagingDataController.container.viewContext)
        }
    }
}
