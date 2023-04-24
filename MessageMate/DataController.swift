//
//  DataController.swift
//  Interactify
//
//  Created by Erick Verleye on 4/23/23.
//

import CoreData
import Foundation


class MessagingDataController: ObservableObject {
    let container = NSPersistentContainer(name: "Messaging")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}


