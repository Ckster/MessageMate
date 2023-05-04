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
    let inDayRange: NSNumber
    var lastRefresh: Date?
        
    init(id: String, updatedTime: String, page: MetaPageModel, platform: String, dateUpdated: Date, inDayRange: NSNumber, lastRefresh: Date? = nil) {
        self.id = id
        self.page = page
        self.updatedTime = Date().facebookStringToDate(fbString: updatedTime)
        self.platform = platform
        self.dateUpdated = dateUpdated
        self.inDayRange = inDayRange
        self.lastRefresh = lastRefresh
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func ==(lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        return lhs.id == rhs.id
    }
}


class InstagramStoryMentionModel: Hashable, Equatable {
    let id: String
    let cdnUrl: String
    
    init (id: String, cdnUrl: String) {
        self.id = id
        self.cdnUrl = cdnUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.cdnUrl)
    }

    static func == (lhs: InstagramStoryMentionModel, rhs: InstagramStoryMentionModel) -> Bool {
        return lhs.cdnUrl == rhs.cdnUrl
    }
    
}


class InstagramStoryReplyModel: Hashable, Equatable {
    let id: String
    let cdnUrl: String
    
    init (id: String, cdnUrl: String) {
        self.id = id
        self.cdnUrl = cdnUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.cdnUrl)
    }

    static func == (lhs: InstagramStoryReplyModel, rhs: InstagramStoryReplyModel) -> Bool {
        return lhs.cdnUrl == rhs.cdnUrl
    }
    
}


class ImageAttachmentModel: Hashable, Equatable {
    let url: String

    init (url: String) {
        self.url = url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.url)
    }

    static func == (lhs: ImageAttachmentModel, rhs: ImageAttachmentModel) -> Bool {
        return lhs.url == rhs.url
    }

}


class VideoAttachmentModel: Hashable, Equatable {
    let url: String

    init (url: String) {
        self.url = url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.url)
    }

    static func == (lhs: VideoAttachmentModel, rhs: VideoAttachmentModel) -> Bool {
        return lhs.url == rhs.url
    }

}


class MessageModel: Hashable, Equatable {
    let id: String
    let uid: UUID = UUID()
    let message: String
    let to: MetaUserModel
    let from: MetaUserModel
    let createdTime: Date
    var opened: NSNumber = NSNumber(value: false)
    var instagramStoryMention: InstagramStoryMentionModel?
    var instagramStoryReply: InstagramStoryReplyModel?
    var imageAttachment: ImageAttachmentModel?
    var videoAttachment: VideoAttachmentModel?
    var dayStarter: NSNumber? = nil
    var conversation: ConversationModel? = nil
    
    init (id: String, message: String, to: MetaUserModel, from: MetaUserModel, dayStarter: NSNumber? = nil, createdTime: Date, instagramStoryMention: InstagramStoryMentionModel? = nil, instagramStoryReply: InstagramStoryReplyModel? = nil, imageAttachment: ImageAttachmentModel? = nil, videoAttachment: VideoAttachmentModel? = nil) {
        self.id = id
        self.message = message
        self.to = to
        self.from = from
       
        self.createdTime = createdTime
        
        self.instagramStoryMention = instagramStoryMention
        self.instagramStoryReply = instagramStoryReply
        self.imageAttachment = imageAttachment
        self.videoAttachment = videoAttachment
        self.dayStarter = dayStarter
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func == (lhs: MessageModel, rhs: MessageModel) -> Bool {
        return lhs.id == rhs.id
    }
}


class MetaUserModel {
    let platform: String
    let name: String?
    let email: String?
    let id: String
    let username: String?
    
    init(platform: String, name: String?, email: String?, username: String?, id: String) {
        self.platform = platform
        self.name = name
        self.email = email
        self.username = username
        self.id = id
    }
}
