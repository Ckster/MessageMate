//
//  FirebaseInitializers.swift
//  Interactify
//
//  Created by Erick Verleye on 5/7/23.
//

import Foundation
import FirebaseFirestore
import FirebaseMessaging


func initializePage(page: MetaPage) {
    initializePageBasicInfo(page: page)
    initializePageBusinessInfo(page: page) {
        initializePageConversationInfo(page: page, completion: {})
    }
}


func initializePageBasicInfo(page: MetaPage) {
    let db = Firestore.firestore()
    
    let pageDoc = db.collection(Pages.name).document(page.id)
    pageDoc.getDocument() {
        doc, error in
        if error == nil && doc != nil {
            if !doc!.exists {
                db.collection(Pages.name).document(page.id).setData(
                    [
                        Pages.fields.INSTAGRAM_ID: page.businessAccountID,
                        Pages.fields.STATIC_PROMPT: "",
                        Pages.fields.NAME: page.name,
                        Pages.fields.APNS_TOKENS: [Messaging.messaging().fcmToken ?? ""]
                    ]
                ) {
                    _ in
                }
            }
            else {
                doc!.reference.updateData([
                    Pages.fields.INSTAGRAM_ID: page.businessAccountID,
                    Pages.fields.NAME: page.name,
                    Pages.fields.APNS_TOKENS: FieldValue.arrayUnion([Messaging.messaging().fcmToken ?? ""])
                ])
            }
        }
    }
}


// TODO: Clean this up
func initializePageBusinessInfo(page: MetaPage, completion: @escaping () -> Void) {
    let db = Firestore.firestore()
    
    let pageDocument = db.collection(Pages.name).document(page.id)
    pageDocument.getDocument {
        doc, error in
        if error == nil && doc != nil {
            if doc!.exists {
                let pageBusinessInformation = db.collection("\(Pages.name)/\(page.id)/\(Pages.collections.BUSINESS_INFO.name)").document(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)
                
                pageBusinessInformation.getDocument {
                    doc, error in
                    if error == nil && doc != nil {
                        if doc!.exists {
                            completion()
                            // TODO: Do some more granular checks
                        }
                        
                        // Initialize the page
                        else {
                            let pageFields = Pages.collections.BUSINESS_INFO.documents.FIELDS.fields
                            
                            pageBusinessInformation.setData([
                                pageFields.BUSINESS_ADDRESS: nil,
                                pageFields.BUSINESS_NAME: nil,
                                pageFields.FAQS: nil,
                                pageFields.INDUSTRY: nil,
                                pageFields.LINKS: nil,
                                pageFields.PRODUCTS_SERVICES: nil,
                                pageFields.SENDER_CHARACTERISTICS: nil,
                                pageFields.SENDER_NAME: nil,
                                pageFields.SPECIFICS: nil
                            ])
                            completion()
                        }
                    }
                    else {
                        completion()
                    }
                }
            }
            
            else {
                pageDocument.setData([:]) {
                    _ in
                    let pageBusinessInformation = db.collection("\(Pages.name)/\(page.id)/\(Pages.collections.BUSINESS_INFO.name)").document(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)
                    
                    pageBusinessInformation.getDocument {
                        doc, error in
                        if error == nil && doc != nil {
                            if doc!.exists {
                                completion()
                                // TODO: Do some more granular checks
                            }
                            
                            // Initialize the page
                            else {
                                let pageFields = Pages.collections.BUSINESS_INFO.documents.FIELDS.fields
                                
                                pageBusinessInformation.setData([
                                    pageFields.BUSINESS_ADDRESS: nil,
                                    pageFields.BUSINESS_NAME: nil,
                                    pageFields.FAQS: nil,
                                    pageFields.INDUSTRY: nil,
                                    pageFields.LINKS: nil,
                                    pageFields.PRODUCTS_SERVICES: nil,
                                    pageFields.SENDER_CHARACTERISTICS: nil,
                                    pageFields.SENDER_NAME: nil,
                                    pageFields.SPECIFICS: nil
                                ])
                                completion()
                            }
                        }
                        else {
                            completion()
                        }
                    }
                }
            }

        }
    }
}


func initializePageConversationInfo(page: MetaPage, completion: @escaping () -> Void) {
    let db = Firestore.firestore()
    if page.id != nil {
        let conversationsCollection = db.collection(Pages.name).document(page.id).collection(Pages.collections.CONVERSATIONS.name)
        conversationsCollection.getDocuments() {
            docs, error in
            if error == nil && docs != nil {
                if docs!.isEmpty {
                    conversationsCollection.document("init").setData(["message": nil]) {
                        _ in
                        completion()
                    }
                }
                else {
                    completion()
                }
            }
            else {
                completion()
            }
        }
    }
}
