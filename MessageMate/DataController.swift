//
//  DataController.swift
//  Interactify
//
//  Created by Erick Verleye on 4/23/23.
//

import CoreData
import Foundation


//class MessagingDataController: ObservableObject {
//    let container = NSPersistentContainer(name: "Messaging")
//
//    init() {
//        container.loadPersistentStores { description, error in
//            if let error = error {
//                print("Core Data failed to load: \(error.localizedDescription)")
//            }
//        }
//    }
//}


//class PersistenceController: ObservableObject {
//    static let shared = PersistenceController()
//
//    let container: NSPersistentContainer
//
//    init() {
//        container = NSPersistentContainer(name: "Messaging")
//        container.loadPersistentStores { _, error in
//            if let error = error {
//                fatalError("Error loading persistent stores: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    func save() {
//        let context = container.viewContext
//        if context.hasChanges {
//            do {
//                try context.save()
//            } catch {
//                let nsError = error as NSError
//                fatalError("Error saving context: \(nsError.localizedDescription)")
//            }
//        }
//    }
//}


