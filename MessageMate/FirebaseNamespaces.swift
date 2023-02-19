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
    static let collections = UsersCollections.self

    // instance attributes
    var name: String
    var fields: UsersFields
    var collections: UsersCollections
    var documentPath: String

    init(uid: String) {

        // This allows you to access the "type attributes" (static let ...) if you are using an instance of the class
        self.name = Users.name
        self.fields = UsersFields()
        self.collections = UsersCollections()
        self.documentPath = "\(Users.name)/\(uid)"
    }
}


struct UsersFields {
    static let DISPLAY_NAME = "display_name"
    static let TOKENS = "tokens"
    static let ONBOARDING_COMPLETED = "onboarding_completed"
    static let LEGAL_AGREEMENT = "legal_agreement"
    static let FACEBOOK_USER_TOKEN = "facebook_user_token"
}

struct UsersCollections {
    static let BUSINESS_INFO = BusinessInfoCollection.self
}

struct BusinessInfoCollection {
    static let name = "business_information"
    static let documents = BusinessInfoDocuments.self
    
    var name: String
    var documents: BusinessInfoDocuments
    
    init() {
        self.name = BusinessInfoCollection.name
        self.documents = BusinessInfoDocuments()
    }
}

struct BusinessInfoDocuments {
    static let FIELDS = BusinessInfoFieldsDocument.self
}

struct BusinessInfoFieldsDocument {
    static let name = "fields"
    static let fields = BusinessInfoFields.self
}

struct BusinessInfoFields {
    static let BUSINESS_ADDRESS = "business_address"
    static let BUSINESS_NAME = "business_name"
    static let FAQS = "faqs"
    static let INDUSTRY = "industry"
    static let LINKS = "links"
    static let PRODUCTS_SERVICES = "products_services"
    static let SENDER_CHARACTERISTICS = "sender_characteristics"
    static let SENDER_NAME = "sender_name"
    static let SPECIFICS = "specifics"
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
