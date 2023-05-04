//
//  MessagingExtensions.swift
//  Interactify
//
//  Created by Erick Verleye on 4/24/23.
//

import Foundation
import SwiftUI
import CoreData

// TODO: I hate this. Find a way to define an extension that can be used for both views without having the same functions twice
extension InfoView {
    func getPageInfo(completion: @escaping () -> Void) {
        Task {
            DispatchQueue.main.async {
                self.session.loadingPageInformation = true
            }
        
            // Get the Business Pages associated with the account
            await self.updateActivePages()
            self.updateSelectedPage() {
                completion()
            }
        }
    }
    
    func updateActivePages() async {
        if self.session.facebookUserToken != nil {
            @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
            
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.session.facebookUserToken!)"
            
            let jsonDataDict = await getRequest(urlString: urlString)
            if jsonDataDict != nil {
                let pages = jsonDataDict!["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var activeIDs: [String] = []
                    let pageCount = pages!.count
                    var pageIndex = 0
                    
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if id != nil && pageAccessToken != nil {
                            activeIDs.append(id!)
                            let existingPage = existingPages.first(where: { $0.id == id! })
                            
                            // Update some fields
                            if existingPage != nil {
                                existingPage!.category = category
                                existingPage!.name = name
                                existingPage!.accessToken = pageAccessToken!
                                existingPage!.active = true
                                await existingPage!.getPageBusinessAccountId()
                                await existingPage!.getProfilePicture()
                            }
                            
                            // Create a new MetaPage instance
                            else {
                                let newPage = MetaPage(
                                    context: self.moc,
                                    id: id!,
                                    accessToken: pageAccessToken!,
                                    active: true,
                                    category: category,
                                    name: name
                                )
                                initializePage(page: newPage)
                                await newPage.getPageBusinessAccountId()
                                await newPage.getProfilePicture()
                            }
                        }
                        
                        if pageIndex == pageCount {
                            // Deactive any pages that were not in response
                            for page in existingPages.lazy {
                         
                                if !activeIDs.contains(page.id) {
                                    page.active = false
                                }
                                
                                else {
                                    page.active  = false
                                }
                            }
                            
                            // Save the changes
                            DispatchQueue.main.async {
                                self.session.activePageIDs = activeIDs
                            }
                            
                            do {
                                try self.moc.save()
                            } catch {
                                print("Error saving A data: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    func updateSelectedPage(completion: @escaping () -> Void) {
        @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
        if self.session.selectedPage == nil {
            // Find the default if there is one
            let defaultPage: MetaPage? = existingPages.first(where: {$0.active?.boolValue ?? false && $0.isDefault?.boolValue ?? false})
            
            // If not set the default to the first active page
            if defaultPage == nil {
                let newDefault = existingPages.first(where: {$0.active?.boolValue ?? false})
                if newDefault != nil {
                    newDefault!.isDefault = true
                    DispatchQueue.main.async {
                        self.session.selectedPage = newDefault!
                    }
                    self.session.subscribeToWebhooks(page: newDefault!) {}
                }
                else {
                    // There are no active pages ...
                }
            }
            
            // If so then set the selected page to it
            else {
                DispatchQueue.main.async {
                    self.session.selectedPage = defaultPage!
                }
                self.session.subscribeToWebhooks(page: defaultPage!) {}
            }
            
        }
        else {
            // First check if the currently selected page is in the set of activated pages and if it is the default. If not switch to defualt if there is one; if not pick the first page and set it to the default
            let existingActivePage: MetaPage? = existingPages.first(where: {$0.active?.boolValue ?? false && $0.id == self.session.selectedPage!.id})
            
            if existingActivePage != nil {
                // Just double check on webhooks
                self.session.subscribeToWebhooks(page: self.session.selectedPage!) {}
            }
            
            else {
                // See if there is a default
                let defaultPage: MetaPage? = existingPages.first(where: {$0.active?.boolValue ?? false && $0.isDefault?.boolValue ?? false})
                
                // Set it if there is one and check webhooks
                if defaultPage != nil {
                    DispatchQueue.main.async {
                        self.session.selectedPage = defaultPage!
                    }
                    self.session.subscribeToWebhooks(page: defaultPage!) {}
                }
                
                // If not then find first active page to set a new default
                let newDefault = existingPages.first(where: {$0.active?.boolValue ?? false})
                if newDefault != nil {
                    newDefault!.isDefault = true
                    DispatchQueue.main.async {
                        self.session.selectedPage = newDefault!
                    }
    
                    self.session.subscribeToWebhooks(page: newDefault!) {}
                }
                else {
                    // There are no active pages ...
                }
            }
        }
        
        do {
            try self.moc.save()
        } catch {
            print("Error saving B data: \(error.localizedDescription)")
        }
        completion()
    }
    
}


extension ConversationsView {
    
    func initializePageInfo() {
        self.moc.perform {
            print(Thread.current, "Thread C")
            Task {
                self.pagesToUpdate = await self.updateActivePages()
            }
        }
    }
    
    func updateActivePages() async -> [MetaPageModel] {
        if self.session.facebookUserToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.session.facebookUserToken!)"
            
            let jsonDataDict = await getRequest(urlString: urlString)
            if jsonDataDict != nil {
                let pages = jsonDataDict!["data"] as? [[String: AnyObject]]
                var newPages: [MetaPageModel] = []
                if pages != nil {
                    let pageCount = pages!.count
                    var pageIndex = 0
                    print("Page response results", pages)
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if id != nil && name != nil && pageAccessToken != nil && category != nil {
                            let pageToUpdate = MetaPageModel(id: id!, name: name!, accessToken: pageAccessToken!, category: category!)
                            newPages.append(pageToUpdate)
                            
                            if pageIndex == pages!.count {
                                print("Setting page to update")
                                return newPages
                            }
                        }
                    }
                }
                else {return []}
            }
            else {return []}
        }
        return []
    }
    
    func updateSelectedPage(completion: @escaping () -> Void) {
        if self.session.selectedPage == nil {
            // Find the default if there is one
            let defaultPage: MetaPage? = self.existingPages.first(where: {$0.active?.boolValue ?? false && $0.isDefault?.boolValue ?? false})
            print("Default Page", defaultPage)
            // If not set the default to the first active page
            if defaultPage == nil {
                let newDefault = self.existingPages.first(where: {$0.active?.boolValue ?? false})
                print("New Default", newDefault)
                if newDefault != nil {
                    newDefault!.isDefault = true
                    DispatchQueue.main.async {
                        self.session.selectedPage = newDefault!
                        do {
                            try self.moc.save()
                        } catch {
                            print("Error saving D data: \(error.localizedDescription)")
                        }
                        self.session.subscribeToWebhooks(page: newDefault!) {}
                        completion()
                    }
                }
                else {
                    // There are no active pages ...
                    do {
                        try self.moc.save()
                    } catch {
                        print("Error saving E data: \(error.localizedDescription)")
                    }
                    completion()
                }
            }
            
            // If so then set the selected page to it
            else {
                DispatchQueue.main.async {
                    self.session.selectedPage = defaultPage!
                    do {
                        try self.moc.save()
                    } catch {
                        print("Error saving F data: \(error.localizedDescription)")
                    }
                    self.session.subscribeToWebhooks(page: defaultPage!) {}
                    completion()
                }
            }
            
        }
        else {
            // First check if the currently selected page is in the set of activated pages and if it is the default. If not switch to defualt if there is one; if not pick the first page and set it to the default
            let existingActivePage: MetaPage? = self.existingPages.first(where: {$0.active?.boolValue ?? false && $0.id == self.session.selectedPage!.id})
            
            if existingActivePage != nil {
                // Just double check on webhooks
                do {
                    try self.moc.save()
                } catch {
                    print("Error saving G data: \(error.localizedDescription)")
                }
                self.session.subscribeToWebhooks(page: self.session.selectedPage!) {}
                completion()
            }
            
            else {
                // See if there is a default
                let defaultPage: MetaPage? = self.existingPages.first(where: {$0.active?.boolValue ?? false && $0.isDefault?.boolValue ?? false})
                
                // Set it if there is one and check webhooks
                if defaultPage != nil {
                    DispatchQueue.main.async {
                        self.session.selectedPage = defaultPage!
                        do {
                            try self.moc.save()
                        } catch {
                            print("Error saving H data: \(error.localizedDescription)")
                        }
                        self.session.subscribeToWebhooks(page: defaultPage!) {}
                        completion()
                    }
                }
                
                // If not then find first active page to set a new default
                let newDefault = self.existingPages.first(where: {$0.active?.boolValue ?? false})
                if newDefault != nil {
                    newDefault!.isDefault = true
                    DispatchQueue.main.async {
                        self.session.selectedPage = newDefault!
                        do {
                            try self.moc.save()
                        } catch {
                            print("Error saving I data: \(error.localizedDescription)")
                        }
                        self.session.subscribeToWebhooks(page: defaultPage!) {}
                        completion()
                    }
                }
                else {
                    // There are no active pages ...
                    do {
                        try self.moc.save()
                    } catch {
                        print("Error saving J data: \(error.localizedDescription)")
                    }
                    completion()
                }
            }
        }
    }
    
    func setSortedConversations() {
        let conversationsToShow : [Conversation] = self.conversationsHook.filter {
            $0.metaPage.id == self.session.selectedPage!.id &&
            $0.inDayRange?.boolValue ?? false
        }
        self.sortedConversations = self.sortConversations(conversations: conversationsToShow)
    }
    
    func decrementConversationsToUpdate(pageID: String?) {
        if pageID == self.session.selectedPage!.id {
            if self.session.conversationsToUpdate > 0 {
                print("BU \(self.session.conversationsToUpdate)")
                self.session.conversationsToUpdate = self.session.conversationsToUpdate - 1
                print("CU \(self.session.conversationsToUpdate)")
                if self.session.conversationsToUpdate == 0 {
                    print("CU")
                    self.session.loadingPageInformation = false
                }
            }
        }
    }

    func refreshUserProfilePictures() {
        let activePages: [MetaPage] = self.existingPages.filter {
            $0.active?.boolValue ?? false
        }
        for page in activePages {
            var userIndex = 0
            for user in self.existingUsers {
                userIndex += 1
                user.getProfilePicture(page: page) {
                    print("USERPP", user)
                    if userIndex == self.existingUsers.count {
                        do {
                            Task {
                                try self.moc.save()
                            }
                        } catch {
                            print("Error saving M data: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func addActivePageListeners() {
        let activePages: [MetaPage] = self.existingPages.filter {
            $0.active?.boolValue ?? false
        }
        for page in activePages {
            self.addConversationListeners(page: page)
        }
    }
    
    func getConversations(page: MetaPageModel, platform: String) async -> [ConversationModel] {
        print("Calling get conversations")
        var urlString = "https://graph.facebook.com/v16.0/\(page.id)/conversations?"
        
        switch platform {
            case "facebook":
                break
            case "instagram":
                urlString = urlString + "platform=instagram"
            default:
                break
        }
        
        urlString = urlString + "&access_token=\(page.accessToken)"
        
        let jsonDataDict = await getRequest(urlString: urlString)
        if jsonDataDict != nil {
            let conversations = jsonDataDict!["data"] as? [[String: AnyObject]]
            var newConversations: [ConversationModel] = []
            if conversations != nil {
                var indexCounter = 0
                print("Conversations length \(conversations!.count)")
                for conversation in conversations! {
                    indexCounter = indexCounter + 1
                    let id = conversation["id"] as? String
                    let updatedTime = conversation["updated_time"] as? String
                    
                    if id != nil && updatedTime != nil {
                        let dateUpdated = Date().facebookStringToDate(fbString: updatedTime!)
                        let inDayRange = dateUpdated.distance(to: Date()) < Double(86400 * conversationDayLimit)
                        let newConversationModel = ConversationModel(id: id!, updatedTime: updatedTime!, page: page, platform: platform, dateUpdated: dateUpdated, inDayRange: NSNumber(value: inDayRange))
                        newConversations.append(newConversationModel)
                    }
                }
                return newConversations
            }
            else { return [] }
        }
        else { return [] }
    }
    
    func getNewMessages(conversation: ConversationModel, cursor: String? = nil, completion: @escaping (([MessageModel], PagingInfo?)) -> Void) {
        print("Runing getMessages")
        print(Thread.current, "Thread D")
        
        if conversation.page.accessToken != nil && conversation.id != nil {
            var urlString = "https://graph.facebook.com/v16.0/\(conversation.id)?fields=messages&access_token=\(conversation.page.accessToken)"
            
            if cursor != nil {
                urlString = urlString + "&after=\(String(describing: cursor))"
            }
            
            if conversation.lastRefresh != nil {
                urlString = urlString + "&since=\(Int(conversation.lastRefresh!.timeIntervalSince1970))"
            }
            
            print("URL string", urlString)
            
                completionGetRequest(urlString: urlString) {
                    jsonDataDict in
                    
                    print(Thread.current, "Thread T")
                    
                    let conversationData = jsonDataDict["messages"] as? [String: AnyObject]
                
                    if conversationData != nil {
                        print(conversationData)
                        
                        // Get paging information
                        var pagingInfo: PagingInfo? = nil
                        let pointerData = conversationData!["paging"] as? [String: AnyObject]
                        if pointerData != nil {
                            let cursorData = pointerData!["cursors"] as? [String: String]
                            if cursorData != nil {
                                pagingInfo = PagingInfo(beforeCursor: cursorData!["before"], afterCursor: cursorData!["after"])
                            }
                        }
                        
                        let messageData = conversationData!["data"] as? [[String: AnyObject]]
                        print("Number of messages: \(messageData!.count)")
                        
                        if messageData != nil {
                            print("Message data not nil")
                            let messagesLen = messageData!.count
                            var indexCounter = 0
                            var newMessages: [MessageModel] = []
                            
                            for message in messageData! {
                                let id = message["id"] as? String
                                let createdTime = message["created_time"] as? String
                                
                                if id != nil && createdTime != nil {
                                    let messageDataURLString = "https://graph.facebook.com/v16.0/\(id!)?fields=id,created_time,from,to,message,story,attachments,shares&access_token=\(conversation.page.accessToken)"
                                    
                                    print("message data url \(messageDataURLString)")
                                    
                                    completionGetRequest(urlString: messageDataURLString) {
                                        messageDataDict in
                                      
                                        print(Thread.current, "Thread U")
                                        
                                        var messageInfo: MessageModel?
                                        switch conversation.platform {
                                        case "instagram":
                                            messageInfo = self.parseInstagramMessage(messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!)
                                        case "facebook":
                                            messageInfo = self.parseFacebookMessage(messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!)
                                        default:
                                            messageInfo = nil
                                        }
                                        
                                        indexCounter = indexCounter + 1
                                        
                                        if messageInfo != nil {
                                            messageInfo!.conversation = conversation
                            
                                            if messageInfo!.id != nil && messageInfo!.message != nil && messageInfo!.createdTime != nil {
                                                newMessages.append(messageInfo!)
                                            }
                                        }
                                        
                                        if indexCounter == messagesLen {
                                            newMessages = newMessages.sorted { $0.createdTime < $1.createdTime }
                                            
                                            var lastDate: Foundation.DateComponents? = nil
                                            for message in newMessages {
                                                
                                                let createdTimeDate = Calendar.current.dateComponents([.month, .day], from: message.createdTime)
                                                var dayStarter = lastDate == nil
                                                if lastDate != nil {
                                                    dayStarter = lastDate!.month! != createdTimeDate.month! || lastDate!.day! != createdTimeDate.day!
                                                }
                                                lastDate = createdTimeDate
                                                message.dayStarter = NSNumber(value: dayStarter)
                                                
                                                print("Done with refreshed message")
                                            }
                                            
                                            print("Setting messages to update")
                                            self.messagesToUpdate = newMessages
                
                                            completion((newMessages, pagingInfo))
                                        }
                                        
                                    }
                                }
                            }
                        }
                    }
                }
        }
        else {
            self.decrementConversationsToUpdate(pageID: conversation.page.id)
        }
    }
    
    func parseInstagramStoryMention(messageDataDict: [String: Any]) -> InstagramStoryMentionModel? {
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let mentionData = storyData!["mention"] as? [String: Any]
            print("Mention data \(mentionData)")
            if mentionData != nil {
                let id = mentionData!["id"] as? String
                let cdnUrl = mentionData!["link"] as? String
                if cdnUrl != nil && id != nil {
                    print("updating instagram story")
                    let newInstagramStoryMention = InstagramStoryMentionModel(id: id!, cdnUrl: cdnUrl!)
                    return newInstagramStoryMention
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseInstagramStoryReply(messageDataDict: [String: Any]) -> InstagramStoryReplyModel? {
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let replyToData = storyData!["reply_to"] as? [String: Any]
            print("Reply data \(replyToData)")
            if replyToData != nil {
                let id = replyToData!["id"] as? String
                let cdnUrl = replyToData!["link"] as? String
                if cdnUrl != nil && id != nil {
                    print("updating instagram story")
                    let newInstagramStoryReply = InstagramStoryReplyModel(id: id!, cdnUrl: cdnUrl!)
                    return newInstagramStoryReply
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseImageAttachment(messageDataDict: [String: Any]) -> ImageAttachmentModel? {
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["image_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            let newImageAttachment = ImageAttachmentModel(url: url!)
                            return newImageAttachment
                        }
                        else {return nil}
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseVideoAttachment(messageDataDict: [String: Any]) -> VideoAttachmentModel? {
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["video_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            let newVideoAttachment = VideoAttachmentModel(url: url!)
                            return newVideoAttachment
                        }
                        else {return nil}
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseInstagramMessage(messageDataDict: [String: Any], message_id: String, createdTime: String) -> MessageModel? {
        let fromDict = messageDataDict["from"] as? [String: AnyObject]
        let toDictList = messageDataDict["to"] as? [String: AnyObject]
        let message = messageDataDict["message"] as? String

        if toDictList != nil {
            let toDict = toDictList!["data"] as? [[String: AnyObject]]

            if toDict!.count == 1 {
                if fromDict != nil && toDict != nil && message != nil {
                    let fromUsername = fromDict!["username"] as? String
                    let fromId = fromDict!["id"] as? String
                    let toUsername = toDict![0]["username"] as? String
                    let toId = toDict![0]["id"] as? String
                    
                    let instagramStoryMention = parseInstagramStoryMention(messageDataDict: messageDataDict)
                    let instagramStoryReply = parseInstagramStoryReply(messageDataDict: messageDataDict)
                    let imageAttachment = parseImageAttachment(messageDataDict: messageDataDict)
                    let videoAttachment = parseVideoAttachment(messageDataDict: messageDataDict)

                    if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil && message != nil {
                        let fromUser = MetaUserModel(platform: "instagram", name: nil, email: nil, username: fromUsername, id: fromId!)
                        let toUser = MetaUserModel(platform: "instagram", name: nil, email: nil, username: toUsername, id: toId!)
                        print("returning message")
                        
                        let createdTime = Date().facebookStringToDate(fbString: createdTime)
                        
                        return MessageModel(id: message_id, message: message!, to: toUser, from: fromUser, createdTime: createdTime, instagramStoryMention: instagramStoryMention, instagramStoryReply: instagramStoryReply, imageAttachment: imageAttachment, videoAttachment: videoAttachment)
                
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseFacebookMessage(messageDataDict: [String: Any], message_id: String, createdTime: String) -> MessageModel? {
        let fromDict = messageDataDict["from"] as? [String: AnyObject]
        let toDictList = messageDataDict["to"] as? [String: AnyObject]
        let message = messageDataDict["message"] as? String

        if toDictList != nil {
            let toDict = toDictList!["data"] as? [[String: AnyObject]]
            
            let imageAttachment = parseImageAttachment(messageDataDict: messageDataDict)

            if toDict!.count == 1 {
                if fromDict != nil && toDict != nil && message != nil {
                    let fromEmail = fromDict!["email"] as? String
                    let fromId = fromDict!["id"] as? String
                    let fromName = fromDict!["name"] as? String
                    
                    let toEmail = toDict![0]["email"] as? String
                    let toName = toDict![0]["name"] as? String
                    let toId = toDict![0]["id"] as? String

                    if fromId != nil && toId != nil {
                        
                        let fromUser = MetaUserModel(platform: "facebook", name: fromName, email: fromEmail, username: nil, id: fromId!)
                        let toUser = MetaUserModel(platform: "facebook", name: toName, email: toEmail, username: nil, id: toId!)
                        print("returning message")
                        
                        let createdTime = Date().facebookStringToDate(fbString: createdTime)
                        
                        return MessageModel(id: message_id, message: message!, to: toUser, from: fromUser, createdTime: createdTime, instagramStoryMention: nil, instagramStoryReply: nil, imageAttachment: imageAttachment, videoAttachment: nil)
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
//    func updateConversations(page: MetaPage) async {
//        for platform in MessagingPlatform.allCases {
//            await self.getConversations(page: page, platform: platform)
//        }
//
//        if let existingConversations = page.conversations! as? Set<Conversation> {
//            let conversationsToUpdate = Array(existingConversations).filter {
//                $0.inDayRange &&
//                $0.updatedTime! > $0.lastRefresh ?? Date(timeIntervalSince1970: 0)
//            }
//
//            for conversation in conversationsToUpdate {
//                self.getNewMessages(page: page, conversation: conversation) {
//                    conversationTuple in
//                    let messages = conversationTuple.0
//                    let pagination = conversationTuple.1
//                    //conversation.pagination = pagination
//                }
//            }
//        }
//    }
    
    func initializeConversationCollection(page: MetaPage, completion: @escaping () -> Void) {
        if page.id != nil {
            let conversationsCollection = self.db.collection(Pages.name).document(page.id).collection(Pages.collections.CONVERSATIONS.name)
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
    
    func addConversationListeners(page: MetaPage) {
        print("Adding conversation listeners")
        
        self.initializeConversationCollection(page: page) {
            if page.id == nil {
                return
            }
            self.db.collection(Pages.name).document(page.id).collection(Pages.collections.CONVERSATIONS.name).addSnapshotListener {
                querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for conversations: \(error!)")
                    return
                }

                querySnapshot?.documentChanges.forEach { diff in
                    if (diff.type == .modified || diff.type == .added) {
                        // TODO: Add support for post share and video
                        
                        print("Snapshot triggered")
                        
                        let data = diff.document.data()
                        let messageText = data["message"] as? String ?? ""
                        let pageId = data["page_id"] as? String
                        let recipientId = data["recipient_id"] as? String
                        let senderId = data["sender_id"] as? String
                        let createdTime = data["created_time"] as? Double
                        let messageId = data["message_id"] as? String
                        let storyMentionUrl = data["story_mention_url"] as? String
                        let imageUrl = data["image_url"] as? String
                        let storyReplyUrl = data["story_reply_url"] as? String
                        let isDeleted = data["is_deleted"] as? Bool
                        
                        if pageId != nil && recipientId != nil && senderId != nil && createdTime != nil && messageId != nil {
                            
                            print("Message id \(messageId)")
                            
                            if page.businessAccountID ?? "" == pageId || page.id == pageId {
                                print("SLA")
                                var conversationFound: Bool = false
                                
                                if let conversationSet = page.conversations as? Set<Conversation> {
                                    print("SLB")
                                    let conversations = Array(conversationSet)
                                    for conversation in conversations {
                                        
                                        if conversation.correspondent != nil && conversation.correspondent!.id == senderId {
                                            print("SLC")
                                            conversationFound = true
                                            let messageDate = Date(timeIntervalSince1970: createdTime! / 1000)
                                            
                                            if let messageSet = conversation.messages as? Set<Message> {
                                                let existingMessages = sortMessages(messages: Array(messageSet))
                                                var existingMessageIDs: [String] = []
                                                for message in existingMessages {
                                                    existingMessageIDs.append(message.id)
                                                }
                
                                                if isDeleted != nil && isDeleted! {
                                                    let messageToDelete = existingMessages.first(where: {$0.id == messageId})
                                                    if messageToDelete != nil {
                                                        self.moc.delete(messageToDelete!)
                                                        return
                                                    }
                                                }
                
                                                else {
                                                    
                                                    // Message should not be added
                                                    if existingMessageIDs.contains(messageId!)
                                                        || messageDate < existingMessages.last?.createdTime ?? Date(timeIntervalSince1970: .zero)
                                                    {return}
                                                    
                                                    // Add the new message
                                                    let lastDate = Calendar.current.dateComponents([.month, .day], from: existingMessages.last!.createdTime)
                                                    let messageCompDate = Calendar.current.dateComponents([.month, .day], from: messageDate)
                                                    let dayStarter = lastDate.month! != messageCompDate.month! || lastDate.day! != messageCompDate.day!
                                                    
                                                    let newMessage = Message(
                                                        context: self.moc,
                                                        id: messageId!,
                                                        createdTime: messageDate,
                                                        message: messageText,
                                                        opened: NSNumber(value: false),
                                                        dayStarter: NSNumber(value: dayStarter),
                                                        conversation: conversation,
                                                        to: page.pageUser!,
                                                        from: conversation.correspondent!
                                                    )
                                                    
                                                    if imageUrl != nil {
                                                        let newImageAttachment = ImageAttachment(
                                                            context: self.moc,
                                                            url: URL(string: imageUrl!),
                                                            message: newMessage
                                                        )
                                                        newMessage.imageAttachment = newImageAttachment
                                                    }
                                                    else {
                                                        if storyMentionUrl != nil {
                                                            // TODO: Get story ID
                                                            let newInstagramStoryMention = InstagramStoryMention(
                                                                context: self.moc,
                                                                id: "1",
                                                                cdnURL: URL(string: storyMentionUrl!),
                                                                message: newMessage
                                                            )
                                                            newMessage.instagramStoryMention = newInstagramStoryMention
                                                        }
                
                                                        else {
                                                            if storyReplyUrl != nil {
                                                                let newInstagramStoryReply = InstagramStoryReply(
                                                                    context: self.moc,
                                                                    id: "1",
                                                                    cdnURL: URL(string: storyReplyUrl!),
                                                                    message: newMessage
                                                                )
                                                                newMessage.instagramStoryReply = newInstagramStoryReply
                                                            }
                                                        }
                                                    }
                                                    
                                                    do {
                                                        Task {
                                                            try self.moc.save()
                                                        }
                                                    } catch {
                                                        print("Error saving Q data: \(error.localizedDescription)")
                                                    }
                                                    
                                                    print("Updating conversation from listener \(senderId)")
                                                    DispatchQueue.main.async {
                                                        self.session.unreadMessages = self.session.unreadMessages + 1
                                                    }
                                                    
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // TODO: Of course facebook doesn't send the conversation ID with the webhook... this should work for now but may be slow. Try to come up with a more efficient way later
                                if !conversationFound && isDeleted != nil && !isDeleted! {
                                    self.initializePageInfo()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
