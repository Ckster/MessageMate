//
//  MessagingDatabaseUpdaters.swift
//  Interactify
//
//  Created by Erick Verleye on 5/3/23.
//

import Foundation
import CoreData


extension ConversationsView {
    func writeNewPages() {
        DispatchQueue.main.async {
            print("Pages to update firing")
            if self.pagesToUpdate == nil {
                return
            }
            for pageModel in self.pagesToUpdate! {
                self.updateOrCreatePage(pageModel: pageModel) {
                    metaPage in
                    if metaPage != nil {
                        Task {
                            await metaPage!.getPageBusinessAccountId()
                            await metaPage!.getProfilePicture()
                            self.updateSelectedPage {
                                var newConversations: [ConversationModel] = []
                                var platformCount = 0
                                for platform in messagingPlatforms {
                                    Task {
                                        let platformConversations = await self.getConversations(page: pageModel, platform: platform)
                                        newConversations.append(contentsOf: platformConversations)
                                        platformCount = platformCount + 1
                                        if platformCount == messagingPlatforms.count {
                                            if metaPage!.id == self.session.selectedPage?.id {
                                                print("Setting conv count w \(newConversations.count) \(metaPage!.id) \(platformCount) \(messagingPlatforms.count)")
                                                self.session.conversationsToUpdate = newConversations.count
                                            }
                                            self.conversationsToUpdate = newConversations
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func writeNewConversations() {
        DispatchQueue.main.async {
            print("CTU firing")
            if self.conversationsToUpdate == nil {
                self.session.conversationsToUpdate = 0
                self.session.loadingPageInformation = false
                return
            }
            
            for conversationModel in conversationsToUpdate! {
                let existingConversation = self.fetchConversation(id: conversationModel.id)
                
                self.updateOrCreateConversation(conversationModel: conversationModel) {
                    conversation in
                    if conversation != nil {
                        conversation!.lastRefresh = existingConversation?.lastRefresh
                        
                        if conversation!.inDayRange && conversation!.updatedTime ?? Date(timeIntervalSince1970: 0) > conversation!.lastRefresh ?? Date(timeIntervalSince1970: 0) {
                            print("Getting new messages")
                            self.getNewMessages(conversation: conversationModel) { _ in}
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
            
            let page = self.fetchPage(id: conversation!.metaPage!.id)
            
            if page == nil {
                return
            }
            
            for newMessageModel in newMessageModels! {
                let newMessage: Message = Message(context: self.moc)
                
                newMessage.conversation = conversation
                
                newMessage.id = newMessageModel.id
                newMessage.message = newMessageModel.message
                newMessage.createdTime = newMessageModel.createdTime
                newMessage.uid = UUID()
                newMessage.opened = true
                newMessage.dayStarter = newMessageModel.dayStarter!
                
                if newMessageModel.imageAttachment != nil {
                    let imageAttachment = ImageAttachment(context: self.moc)
                    imageAttachment.uid = UUID()
                    imageAttachment.url = URL(string: newMessageModel.imageAttachment!.url) ?? URL(string: "")
                    newMessage.imageAttachment = imageAttachment
                }
                if newMessageModel.instagramStoryMention != nil {
                    let instagramStoryMention = InstagramStoryMention(context: self.moc)
                    instagramStoryMention.uid = UUID()
                    instagramStoryMention.id = newMessageModel.instagramStoryMention!.id
                    instagramStoryMention.cdnURL =  URL(string: newMessageModel.instagramStoryMention!.cdnUrl) ?? URL(string: "")
                    newMessage.instagramStoryMention = instagramStoryMention
                }
                if newMessageModel.instagramStoryReply != nil {
                    let instagramStoryReply = InstagramStoryReply(context: self.moc)
                    instagramStoryReply.uid = UUID()
                    instagramStoryReply.id = newMessageModel.instagramStoryReply!.id
                    instagramStoryReply.cdnURL = URL(string: newMessageModel.instagramStoryReply!.cdnUrl) ?? URL(string: "")
                    newMessage.instagramStoryReply = instagramStoryReply
                }
                if newMessageModel.videoAttachment != nil {
                    let videoAttachment = VideoAttachment(context: self.moc)
                    videoAttachment.uid = UUID()
                    videoAttachment.url = URL(string: newMessageModel.videoAttachment!.url) ?? URL(string: "")
                    newMessage.videoAttachment = videoAttachment
                }
                
                print("New / update user")
                print(newMessageModel.to.id)
                print(newMessageModel.from.id)
                
                self.updateOrCreateUser(userModel: newMessageModel.to) {
                    toUser in
                    self.updateOrCreateUser(userModel: newMessageModel.from) {
                        fromUser in
                        newMessage.to = toUser
                        newMessage.from = fromUser
                    }
                }
            }
            conversation?.lastRefresh = Date()
            let userList = conversation?.updateCorrespondent()
            if userList?.count ?? 0 > 0 {
                page!.pageUser = userList![1]
            }

            do {
                try self.moc.save()
            } catch {
                print("Error saving A1 data: \(error.localizedDescription)")
            }
            
            print("AU \(conversation!.metaPage?.id)")
            self.decrementConversationsToUpdate(pageID: conversation?.metaPage?.id)
            
            print("Updated messages for conversation")
        }
    }
    

    func writeSearchResults(searchText: String) {
        if self.session.selectedPage == nil {
            return
        }
        
        if !searchText.isEmpty {
            DispatchQueue.main.async {
                var filteredCorrespondents: [Conversation] = []
                var filteredMessages: [Conversation] = []
                
                let conversationsToShow : [Conversation] = self.conversationsHook.filter {
                    $0.metaPage?.id == self.session.selectedPage!.id! &&
                    $0.inDayRange
                }
                
                for conversation in conversationsToShow {
                    
                    // Reset
                    //conversation.messagesToScrollTo = nil
                    
                    // See if correspondent needs to be added to search results
                    let correspondentContains = (conversation.correspondent?.displayName() ?? "").lowercased().contains(searchText.lowercased())
                    if correspondentContains {
                        filteredCorrespondents.append(
                            conversation
                        )
                    }
                    
                    // See which messages need to be added to search result
                    var messageFound: Bool = false
                    if let messageSet = conversation.messages as? Set<Message> {
                        let messages = Array(messageSet)
                        for message in messages {
                            if message.message == nil {
                                continue
                            }
                            if message.message!.lowercased().contains(searchText.lowercased()) {
                                
                                conversation.messageToScrollTo = message
                                
                                messageFound = true
                                
                            }
                        }
                        
                        if messageFound {
                            filteredMessages.append(
                                conversation
                            )
                        }
                    }
                }
                
                self.corresponsdentsSearch = self.sortConversations(conversations: filteredCorrespondents)
                self.messagesSearch = self.sortConversations(conversations: filteredMessages)
                try? self.moc.save()
            }
        }
        else {
            self.waitingForReset = true
            self.resetSearch()
        }
    }
    
    func resetSearch() {
        DispatchQueue.main.async {
            print("Resetting")
            self.corresponsdentsSearch = []
            self.messagesSearch = []
            let conversationsToShow : [Conversation] = self.conversationsHook.filter {
                $0.metaPage?.id == self.session.selectedPage!.id! &&
                $0.inDayRange
            }
            for conversation in conversationsToShow {
                conversation.messageToScrollTo = nil
                if let messageSet = conversation.messages as? Set<Message> {
                    let messages = Array(messageSet)
                    for message in messages {
                        message.highlight = false
                    }
                }
            }
            
            self.sortedConversations = self.sortConversations(conversations: conversationsToShow)
            self.waitingForReset = false
            try? self.moc.save()
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
    
    func updateOrCreatePage(pageModel: MetaPageModel, completion: @escaping (MetaPage?) -> Void) {
        let existingPage = self.fetchPage(id: pageModel.id)
        
        var outPage: MetaPage? = nil
        
        // Update some fields
        if existingPage != nil {
            print("Existing page", existingPage)
            existingPage!.category = pageModel.category
            existingPage!.name = pageModel.name
            existingPage!.accessToken = pageModel.accessToken
            existingPage!.active = true
            outPage = existingPage
        }
        
        // Create a new MetaPage instance
        else {
            let newPage = MetaPage(context: self.moc)
            
            newPage.uid = UUID()
            newPage.id = pageModel.id
            newPage.category = pageModel.category
            newPage.name = pageModel.name
            newPage.accessToken = pageModel.accessToken
            newPage.active = true
            initializePage(page: newPage)
            newPage.isDefault = false
            outPage = newPage
        }
        
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
            existingConversation!.metaPage = existingPage
            outConversation = existingConversation
        }
        
        // Create new instance
        else {
            let newConversation = Conversation(context: self.moc)
            newConversation.uid = UUID()
            newConversation.id = conversationModel.id
            newConversation.platform = conversationModel.platform
            newConversation.updatedTime = conversationModel.dateUpdated
            newConversation.inDayRange = conversationModel.inDayRange
            newConversation.metaPage = existingPage
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
    
    
    // Users
    func fetchUser(id: String) -> MetaUser? {
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
    
    func updateOrCreateUser(userModel: MetaUserModel, completion: @escaping (MetaUser?) -> Void) {
        let existingUser = self.fetchUser(id: userModel.id)
        
        var outUser: MetaUser? = nil
        
        if existingUser != nil {
            existingUser!.name = userModel.name
            existingUser!.email = userModel.email
            existingUser!.username = userModel.username
            existingUser!.platform = userModel.platform
            outUser = existingUser
        }
        
        else {
            let newUser = MetaUser(context: self.moc)
            newUser.uid = UUID()
            newUser.id = userModel.id
            newUser.name = userModel.name
            newUser.email = userModel.email
            newUser.username = userModel.username
            newUser.platform = userModel.platform
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
}
