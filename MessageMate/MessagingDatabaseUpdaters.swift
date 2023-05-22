//
//  MessagingDatabaseUpdaters.swift
//  Interactify
//
//  Created by Erick Verleye on 5/3/23.
//

import Foundation
import CoreData
import SwiftUI


extension ContentView {
    func writeNewPages() {
        DispatchQueue.main.async {
            do {
                print("Pages to update firing")
                if self.pagesToUpdate == nil {
                    return
                }
                for pageModel in self.pagesToUpdate! {
                    print("Updating page model \(pageModel)")
                    self.updateOrCreatePage(pageModel: pageModel) {
                        metaPage in
                        if metaPage != nil {
                            Task {
                                metaPage!.loading = true
                                await metaPage!.getPageBusinessAccountId() {
                                    businessAccountID in
                                    DispatchQueue.main.async {
                                        metaPage!.businessAccountID = businessAccountID
                                    }
                                }
                                await metaPage!.getProfilePicture() {
                                    profilePictureURL in
                                    DispatchQueue.main.async {
                                        metaPage!.photoURL = profilePictureURL
                                    }
                                }
                                
                                // This won't overwrite existing info, just initiaize things that don't exist
                                initializePage(page: metaPage!)
                                
                                self.updateSelectedPage {
                                    self.session.loadingPageInformation = false
                                    var newConversations: [ConversationModel] = []
                                    var platformCount = 0
                                    for platform in messagingPlatforms {
                                        Task {
                                            let platformConversations = await self.getConversations(page: pageModel, platform: platform)
                                            newConversations.append(contentsOf: platformConversations)
                                            platformCount = platformCount + 1
                                            if platformCount == messagingPlatforms.count {
                                                print("Setting conv count w \(newConversations.count) \(metaPage!.id) \(platformCount) \(messagingPlatforms.count)")
                                                self.session.conversationsToUpdateByPage[metaPage!.id] = newConversations.count
                                                self.conversationsToUpdate = newConversations
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if self.pagesToUpdate!.count == 0 {
                    self.unloadActivePageListeners()
                }
            }
            catch {
            }
        }
    }
    
    func writeNewConversations() {
        DispatchQueue.main.async {
            print("CTU firing")
            if self.conversationsToUpdate == nil {
                return
            }
            
            for conversationModel in conversationsToUpdate! {
                let existingConversation = self.fetchConversation(id: conversationModel.id)
                
                self.updateOrCreateConversation(conversationModel: conversationModel) {
                    conversation in
                    if conversation != nil {
                        conversation!.lastRefresh = existingConversation?.lastRefresh
                        
                        if conversation!.inDayRange?.boolValue ?? false && conversation!.updatedTime ?? Date(timeIntervalSince1970: 0) > conversation!.lastRefresh ?? Date(timeIntervalSince1970: 0) {
                            print("Getting new messages")
                            conversationModel.lastRefresh = conversation!.lastRefresh
                            self.getNewMessages(conversation: conversationModel) {_ in}
                        }
                        else {
                            print("NO message update")
                            self.decrementConversationsToUpdate(pageID: conversationModel.page.id)
                        }
                    }
                }
            }
        }
    }
    
    func writeNewMessages() {
        DispatchQueue.main.async {
            let newMessageModels = self.messagesToUpdate
            print("Updating message")
            if newMessageModels == nil || newMessageModels!.count == 0 {
                return
            }
        
            let conversation = self.fetchConversation(id: newMessageModels!.first!.conversation!.id)
            
            if conversation == nil {
                return
            }
            
            let page = self.fetchPage(id: conversation!.metaPage.id)
            
            if page == nil {
                return
            }
            
            var noErrors: Bool = true
            for newMessageModel in newMessageModels! {
                
                self.updateOrCreateMetaUser(userModel: newMessageModel.to) {
                    toUser in
                    self.updateOrCreateMetaUser(userModel: newMessageModel.from) {
                        fromUser in
                        if toUser != nil && fromUser != nil {
                            self.createMessage(messageModel: newMessageModel, conversation: conversation!, to: toUser!, from: fromUser!) {
                                newMessage in
                                if newMessage == nil {
                                    noErrors = false
                                }
                            }
                        }
                        else {
                            noErrors = false
                        }
                    }
                }
            }
            
            if noErrors {
                conversation!.lastRefresh = Date()
            }
            
            let userList = conversation?.updateCorrespondent()
            if userList?.count ?? 0 > 0 {
                page!.metaUser = userList![1]
            }
            self.decrementConversationsToUpdate(pageID: conversation!.metaPage.id)
            
        }
    }
    
    func saveContext(completion: @escaping (Error?) -> Void) {
        guard self.moc.hasChanges else {
            completion(nil)
            return
        }
        
        do {
            try self.moc.performAndWait {
                try self.moc.save()
            }
            completion(nil)
        } catch let error {
            print("Error saving context: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    
    // Pages
    func fetchPage(id: String) -> MetaPage? {
        let fetchRequest: NSFetchRequest<MetaPage> = MetaPage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        do {
            let pages = try moc.fetch(fetchRequest)
            return pages.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchCurrentUsersPages() -> [MetaPage]? {
        if let id = self.session.user.uid {
            let fetchRequest: NSFetchRequest<MetaPage> = MetaPage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "firebaseUser.id == %@", id)
            do {
                let pages = try moc.fetch(fetchRequest)
                return pages
            } catch {
                print("Error fetching user: \(error.localizedDescription)")
                return nil
            }
        }
        else {
            return nil
        }
    }
    
    func updateOrCreatePage(pageModel: MetaPageModel, completion: @escaping (MetaPage?) -> Void) {
        print("RR")
        let existingPage = self.fetchPage(id: pageModel.id)
        let firebaseUser = self.fetchCurrentFirebaseUser() {
            firebaseUser in
            
            // Need to have Firebase User
            if firebaseUser == nil {
                completion(nil)
                return
            }
            
            var outPage: MetaPage? = nil
            
            // Update some fields
            if existingPage != nil {
                print("Existing page", existingPage)
                existingPage!.category = pageModel.category
                existingPage!.name = pageModel.name
                existingPage!.accessToken = pageModel.accessToken
                existingPage!.firebaseUser = firebaseUser!
                outPage = existingPage
            }
            
            // Create a new MetaPage instance
            else {
                let newPage = MetaPage(
                    context: self.moc,
                    id: pageModel.id,
                    accessToken: pageModel.accessToken,
                    loading: NSNumber(value: true),
                    isDefault: false,
                    category: pageModel.category,
                    name: pageModel.name,
                    firebaseUser: firebaseUser!
                )
                outPage = newPage
            }
            
            print("Calling save")
            
            self.saveContext() {
                error in
                if error == nil {
                    completion(outPage!)
                }
                else {
                    print(error)
                    completion(nil)
                }
            }
            
            
        }
    }
    
    // Conversations
    func fetchConversation(id: String) -> Conversation? {
        let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        do {
            let conversations = try moc.fetch(fetchRequest)
            return conversations.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateOrCreateConversation(conversationModel: ConversationModel, completion: @escaping (Conversation?) -> Void) {
        let existingPage = self.fetchPage(id: conversationModel.page.id)
        let existingConversation = self.fetchConversation(id: conversationModel.id)
        
        var outConversation: Conversation?
        
        // Update some fields...
        if existingConversation != nil {
            existingConversation!.updatedTime = conversationModel.dateUpdated
            existingConversation!.inDayRange = conversationModel.inDayRange
            outConversation = existingConversation
        }
        
        // Create new instance
        else {
            print("Creating new conversation")
            let newConversation = Conversation(
                context: self.moc,
                id: conversationModel.id,
                updatedTime: conversationModel.dateUpdated,
                platform: conversationModel.platform,
                inDayRange: conversationModel.inDayRange,
                metaPage: existingPage!
            )
            outConversation = newConversation
        }
        
        self.saveContext() {
            error in
            if error == nil {
                completion(outConversation!)
            }
            else {
                print(error)
                completion(nil)
            }
        }
        
    }
    
    // Messages
    func fetchMessage(id: String) -> Message? {
        let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        do {
            let conversations = try moc.fetch(fetchRequest)
            return conversations.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    func createMessage(messageModel: MessageModel, conversation: Conversation, to: MetaUser, from: MetaUser, completion: @escaping (Message?) -> Void) {
        print("starting creating message")
        let existingMessage = self.fetchMessage(id: messageModel.id)
        if existingMessage != nil {
            completion(nil)
        }
        
        print("creating message")
        
        let newMessage: Message = Message(
            context: self.moc,
            id: messageModel.id,
            createdTime: messageModel.createdTime, message: messageModel.message,
            opened: true,
            dayStarter: messageModel.dayStarter ?? false,
            conversation: conversation,
            to: to,
            from: from
        )
        
        if messageModel.instagramStoryMention != nil {
            let instagramStoryMention = InstagramStoryMention(
                context: self.moc,
                id: messageModel.instagramStoryMention!.id,
                cdnURL: URL(string: messageModel.instagramStoryMention!.cdnUrl),
                message: newMessage
            )
            newMessage.instagramStoryMention = instagramStoryMention
        }
        
        if messageModel.instagramStoryReply != nil {
            let instagramStoryReply = InstagramStoryReply(
                context: self.moc,
                id: messageModel.instagramStoryReply!.id,
                cdnURL: URL(string: messageModel.instagramStoryReply!.cdnUrl),
                message: newMessage
            )
            newMessage.instagramStoryReply = instagramStoryReply
        }
        
        if messageModel.instagramPost != nil {
            print("Adding instagram post")
            let instagramPost = InstagramPost(
                context: self.moc,
                id: messageModel.instagramPost!.id,
                cdnURL: URL(string: messageModel.instagramPost!.cdnUrl),
                mediaType: messageModel.instagramPost!.mediaType,
                message: newMessage
            )
            newMessage.instagramPost = instagramPost
        }
        if messageModel.imageAttachment != nil {
            let imageAttachment = ImageAttachment(
                context: self.moc,
                url: URL(string: messageModel.imageAttachment!.url),
                message: newMessage,
                id: messageModel.id
            )
            newMessage.imageAttachment = imageAttachment
        }
        if messageModel.videoAttachment != nil {
            let videoAttachment = VideoAttachment(
                context: self.moc,
                url: URL(string: messageModel.videoAttachment!.url),
                message: newMessage,
                id: messageModel.id
            )
            newMessage.videoAttachment = videoAttachment
        }
        
        completion(newMessage)
        
//        self.saveContext() {
//            error in
//            if error == nil {
//
//            }
//            else {
//                print(error)
//                completion(nil)
//            }
//        }
        
    }
    
    
    // Meta Users
    func fetchMetaUser(id: String) -> MetaUser? {
        let fetchRequest: NSFetchRequest<MetaUser> = MetaUser.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        do {
            let users = try moc.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateOrCreateMetaUser(userModel: MetaUserModel, completion: @escaping (MetaUser?) -> Void) {
        let existingUser = self.fetchMetaUser(id: userModel.id)
        
        var outUser: MetaUser? = nil
        
        if existingUser != nil {
            existingUser!.name = userModel.name
            existingUser!.email = userModel.email
            existingUser!.username = userModel.username
            existingUser!.platform = userModel.platform
            outUser = existingUser
        }
        
        else {
            let newUser = MetaUser(
                context: self.moc,
                id: userModel.id,
                platform: userModel.platform,
                email: userModel.email,
                name: userModel.name,
                username: userModel.username
            )
            outUser = newUser
        }
        
        self.saveContext() {
            error in
            if error == nil {
                completion(outUser!)
            }
            else {
                print(error)
                completion(nil)
            }
        }
    }
    
    // Firebase Users
    func fetchCurrentFirebaseUser(completion: @escaping (FirebaseUser?) -> Void) {
        if let id = self.session.user.uid {
            let fetchRequest: NSFetchRequest<FirebaseUser> = FirebaseUser.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            do {
                let users = try moc.fetch(fetchRequest)
                let user = users.first
                if user != nil {
                    completion(user!)
                }
                else {
                    self.createCurrentFirebaseUser() {
                        user in
                        completion(user)
                    }
                }
            } catch {
                print("Error fetching user: \(error.localizedDescription)")
                completion(nil)
            }
        }
        else {
            completion(nil)
        }
    }
    
    func createCurrentFirebaseUser(completion: @escaping (FirebaseUser?) -> Void) {
        if self.session.user.uid != nil {
            let newUser = FirebaseUser(
                context: self.moc,
                id: self.session.user.uid!
            )
            
            self.saveContext() {
                error in
                if error == nil {
                    completion(newUser)
                }
                else {
                    print(error)
                    completion(nil)
                }
            }
        }
        else {
            completion(nil)
        }
        
    }
    
}
