//
//  FirebaseNamespaces.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import Foundation

struct Users {
    // type attributes
    static let name = "users"
    static let fields = UsersFields.self
    
    // instance attributes
    var name: String
    var fields: UsersFields
    var documentPath: String
    
    init(uid: String) {
        
        // This allows you to access the "type attributes" (static let ...) if you are using an instance of the class
        self.name = Users.name
        self.fields = UsersFields()
        self.documentPath = "\(Users.name)/\(uid)"
    }
}


struct UsersFields {
    static let DISPLAY_NAME = "display_name"
    static let TOKENS = "tokens"
    static let TUTORIAL_COMPLETED = "tutorial_completed"
    static let LEGAL_AGREEMENT = "legal_agreement"
}


struct AppSettings {
    static let name = "app_settings"
    static let documents = AppSettingsDocuments.self
}


// Documents structures
class AppSettingsDocuments {
    static let LINKS = LinksDocument.self
}


struct LinksDocument {
    static let name = "links"
    static let fields = LinksFields.self
}


struct LinksFields {
    static let PRIVACY_POLICY = "privacy_policy"
    static let TERMS_OF_SERVICE = "terms_of_service"
}
