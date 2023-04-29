//
//  DataModels.swift
//  Interactify
//
//  Created by Erick Verleye on 4/28/23.
//

import Foundation

class MetaPageModel: Hashable, Equatable {
    let id: String
    let name: String
    let accessToken: String
    let category: String
    
    init(id: String, name: String, accessToken: String, category: String) {
        self.id = id
        self.name = name
        self.accessToken = accessToken
        self.category = category
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func ==(lhs: MetaPageModel, rhs: MetaPageModel) -> Bool {
        return lhs.id == rhs.id
    }
}

class ConversationModel: Hashable, Equatable {
    let id: String
    let updatedTime: Date?
    let page: MetaPageModel
    var messagesInitialized: Bool = false
    let platform: String
    let dateUpdated: Date
    let inDayRange: Bool
        
    init(id: String, updatedTime: String, page: MetaPageModel, platform: String, dateUpdated: Date, inDayRange: Bool) {
        self.id = id
        self.page = page
        self.updatedTime = Date().facebookStringToDate(fbString: updatedTime)
        self.platform = platform
        self.dateUpdated = dateUpdated
        self.inDayRange = inDayRange
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func ==(lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        return lhs.id == rhs.id
    }
}
