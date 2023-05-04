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
                print("Updating page model \(pageModel)")
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
                        
                        if conversation!.inDayRange?.boolValue ?? false && conversation!.updatedTime ?? Date(timeIntervalSince1970: 0) > conversation!.lastRefresh ?? Date(timeIntervalSince1970: 0) {
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
            
            let page = self.fetchPage(id: conversation!.metaPage.id)
            
            if page == nil {
                return
            }
            
            var noErrors: Bool = true
            for newMessageModel in newMessageModels! {
                
                self.updateOrCreateUser(userModel: newMessageModel.to) {
                    toUser in
                    self.updateOrCreateUser(userModel: newMessageModel.from) {
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
                page!.pageUser = userList![1]
            }
            self.decrementConversationsToUpdate(pageID: conversation!.metaPage.id)
            
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
                    $0.metaPage.id == self.session.selectedPage!.id &&
                    $0.inDayRange?.boolValue ?? false
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
                            if message.message.lowercased().contains(searchText.lowercased()) {
                                
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
            self.corresponsdentsSearch = []
            self.messagesSearch = []
            let conversationsToShow : [Conversation] = self.conversationsHook.filter {
                $0.metaPage.id == self.session.selectedPage!.id &&
                $0.inDayRange?.boolValue ?? false
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
    
    func updateOrCreatePage(pageModel: MetaPageModel, completion: @escaping (MetaPage?) -> Void) {
        print("RR")
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
            let newPage = MetaPage(
                context: self.moc,
                id: pageModel.id,
                accessToken: pageModel.accessToken,
                active: true,
                isDefault: false,
                category: pageModel.category,
                name: pageModel.name
            )
            initializePage(page: newPage)
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
            outConversation = existingConversation
        }
        
        // Create new instance
        else {
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
        let existingMessage = self.fetchMessage(id: messageModel.id)
        if existingMessage == nil {
            completion(nil)
        }
        
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
        
        if messageModel.imageAttachment != nil {
            let imageAttachment = ImageAttachment(
                context: self.moc,
                url: URL(string: messageModel.imageAttachment!.url),
                message: newMessage
            )
            newMessage.imageAttachment = imageAttachment
        }
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
        if messageModel.videoAttachment != nil {
            let videoAttachment = VideoAttachment(
                context: self.moc,
                url: URL(string: messageModel.videoAttachment!.url),
                message: newMessage
            )
            newMessage.videoAttachment = videoAttachment
        }
        
        self.saveContext() {
            error in
            if error == nil {
                completion(newMessage)
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
}
