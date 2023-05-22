//
//  MessagingExtensions.swift
//  Interactify
//
//  Created by Erick Verleye on 4/24/23.
//

import Foundation
import SwiftUI
import CoreData


extension ContentView {
    
    func initializePageInfo() {
        self.moc.perform {
            self.session.loadingPageInformation = true
            print(Thread.current, "Thread C")
            Task {
                self.pagesToUpdate = await self.updateActivePages()
                if self.session.initializingPageOnOnboarding != nil && self.session.initializingPageOnOnboarding! {
                    self.session.initializingPageOnOnboarding = false
                }
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
                    if pages!.count == 0 {
                        return []
                    }
                }
                else {return []}
            }
            else {return []}
        }
        return []
    }
    
    func updateSelectedPage(completion: @escaping () -> Void) {
        let currentUserPages = self.fetchCurrentUsersPages()
        
        if currentUserPages == nil {
            completion()
        }
        
        if self.session.selectedPage == nil {
            print(Thread.current, "USP")
            
            // Find the default if there is one
            let defaultPage: MetaPage? = currentUserPages!.first(where: {$0.isDefault?.boolValue ?? false})
            print("Default Page", defaultPage)
            // If not set the default to the first active page
            if defaultPage == nil {
                let newDefault = currentUserPages!.first
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
            let existingActivePage: MetaPage? = currentUserPages!.first(where: {$0.id == self.session.selectedPage!.id})
            
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
                let defaultPage: MetaPage? = currentUserPages!.first(where: {$0.isDefault?.boolValue ?? false})
                
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
                let newDefault = currentUserPages!.first
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
    
    func decrementConversationsToUpdate(pageID: String) {
        if let conversationsToUpdate = self.session.conversationsToUpdateByPage[pageID] {
            if conversationsToUpdate > 0 {
                self.session.conversationsToUpdateByPage[pageID] = self.session.conversationsToUpdateByPage[pageID]! - 1
                if self.session.conversationsToUpdateByPage[pageID]! == 0 {
                    print("CU")
                    self.refreshUserProfilePictures()
                    if let metaPage = self.fetchPage(id: pageID) {
                        self.addConversationListeners(page: metaPage)
                        metaPage.loading = NSNumber(value: false)
                        self.saveContext() {
                            error in
                            if error == nil {
                            }
                            else {
                                print(error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func refreshUserProfilePictures() {
        print("Calling refresh profile pictures")
        let currentUserPages = self.fetchCurrentUsersPages()
        if currentUserPages == nil {
            return
        }
        var pageCount = 0
        for page in currentUserPages! {
            print("RPPP", page)
            var conversationCount = 0
            if let conversations = page.conversations as? Set<Conversation> {
                print("RPPC \(conversations.count)")
                for conversation in conversations {
                    if let correspondent = conversation.correspondent {
                        correspondent.getProfilePicture(page: page) {
                            conversationCount = conversationCount + 1
                            if conversationCount == conversations.count {
                                pageCount = pageCount + 1
                            }
                        }
                    }
                    else {
                        conversationCount = conversationCount + 1
                        if conversationCount == conversations.count {
                            pageCount = pageCount + 1
                        }
                    }
                }
            }
            else {
                pageCount = pageCount + 1
            }
            if pageCount == currentUserPages!.count {
                try? self.moc.save()
            }
        }
    }
    
    func addActivePageListeners() {
        if let currentUserPages = self.fetchCurrentUsersPages() {
            for page in currentUserPages {
                print("Adding active listeners")
                self.addConversationListeners(page: page)
            }
        }
    }
    
    func unloadActivePageListeners() {
        if let currentUserPages = self.fetchCurrentUsersPages() {
            for page in currentUserPages {
                page.loading = NSNumber(value: false)
            }
            do {
                try self.moc.save()
            }
            catch {}
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
        print("Runing getMessages \(conversation)")
        print(Thread.current, "Thread D")
        
        if conversation.page.accessToken != nil && conversation.id != nil {
            var urlString = "https://graph.facebook.com/v16.0/\(conversation.id)?fields=messages&access_token=\(conversation.page.accessToken)"
            
            // TODO: Fix this
            if cursor != nil {
                urlString = urlString + "&after=\(String(describing: cursor))"
            }
            
            if conversation.lastRefresh != nil {
                print("since parameter \("&since=\(conversation.lastRefresh!)")")
                urlString = urlString + "&since=\(Int(conversation.lastRefresh!.timeIntervalSince1970))"
            }
            
            print("URL string", urlString)
            
            completionGetRequest(urlString: urlString) {
                jsonDataDict in
                
                if jsonDataDict == nil {
                    self.decrementConversationsToUpdate(pageID: conversation.page.id)
                    completion(([], nil))
                }
                
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
                            let isUnsupported = message["is_unsupported"] as? Bool
                            let id = message["id"] as? String
                            let createdTime = message["created_time"] as? String
                            
                            Task {
                                if id != nil && createdTime != nil && !(isUnsupported ?? false) {
                                    let messageDataURLString = "https://graph.facebook.com/v16.0/\(id!)?fields=id,created_time,from,to,message,story,attachments,shares&access_token=\(conversation.page.accessToken)"
                                    
                                    print("message data url \(messageDataURLString)")
                                    
                                    if let messageDataDict = await getRequest(urlString: messageDataURLString) {
                                        print(Thread.current, "Thread U")
                                        
                                        var messageInfo: MessageModel?
                                        switch conversation.platform {
                                        case "instagram":
                                            messageInfo = await self.parseInstagramMessage(messageDataDict: messageDataDict, messageId: id!, createdTime: createdTime!, accessToken: conversation.page.accessToken)
                                            
                                        case "facebook":
                                            messageInfo = self.parseFacebookMessage(messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!)
                                        default:
                                            messageInfo = nil
                                        }
                                        
                                        if messageInfo != nil {
                                            messageInfo!.conversation = conversation
                                            
                                            if messageInfo!.id != nil && messageInfo!.message != nil && messageInfo!.createdTime != nil {
                                                newMessages.append(messageInfo!)
                                            }
                                        }
                                    }
                                }
                                indexCounter = indexCounter + 1
                                
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
                        if messagesLen == 0 {
                            self.decrementConversationsToUpdate(pageID: conversation.page.id)
                            completion(([], nil))
                        }
                    }
                    else {
                        self.decrementConversationsToUpdate(pageID: conversation.page.id)
                        completion(([], nil))
                    }
                }
                else {
                    self.decrementConversationsToUpdate(pageID: conversation.page.id)
                    completion(([], nil))
                }
            }
        }
        else {
            self.decrementConversationsToUpdate(pageID: conversation.page.id)
            completion(([], nil))
        }
    }
    
    func parseInstagramStoryMention(messageId: String, messageDataDict: [String: Any]) -> InstagramStoryMentionModel? {
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let mentionData = storyData!["mention"] as? [String: Any]
            print("Mention data \(mentionData)")
            if mentionData != nil {
                if mentionData!.keys.contains("link") {
                    let cdnUrl = mentionData!["link"] as? String ?? ""
                    // Once the story no longer exists the cdnURL will be nil but should still make the object and then not show user a story, just that they were mentioned
                    print("updating instagram story")
                    let newInstagramStoryMention = InstagramStoryMentionModel(id: messageId, cdnUrl: cdnUrl)
                    return newInstagramStoryMention
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseInstagramStoryReply(messageId: String, messageDataDict: [String: Any]) -> InstagramStoryReplyModel? {
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let replyToData = storyData!["reply_to"] as? [String: Any]
            print("Reply data \(replyToData)")
            if replyToData != nil {
                if replyToData!.keys.contains("link") {
                    let cdnUrl = replyToData!["link"] as? String ?? ""
                    print("updating instagram story")
                    let newInstagramStoryReply = InstagramStoryReplyModel(id: messageId, cdnUrl: cdnUrl)
                    return newInstagramStoryReply
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseInstagramPost(messageId: String, postDataDict: [String: Any]) async -> InstagramPostModel? {
        print("IP \(postDataDict)")
        print("Attachments \(postDataDict)")
        let attachmentsData = postDataDict["data"] as? [[String: Any]]
        print("Attachments data \(attachmentsData)")
        if attachmentsData != nil {
            let firstAttachment = attachmentsData!.first
            if firstAttachment != nil {
                if let url = firstAttachment!["link"] as? String {
                    print("updating instagram post")
                    
                    // Must resolve the media type (image or video)
                    if let mediaResponse = await headRequest(urlString: url) {
                        if let contentType = mediaResponse["Content-Type"] as? String {
                            print("content Type", contentType)
                            let mediaType: String? = contentType == "video/mp4" ? "video" : ["image/jpeg", "image/heic", "image/webp"].contains(contentType) ? "image" : nil
                            if mediaType != nil {
                                let newInstagramPost = InstagramPostModel(id: messageId, cdnUrl: url, mediaType: mediaType!)
                                return newInstagramPost
                            }
                        }
                    }
                }
                else {return nil}
            }
            else {return nil}
        }
      return nil
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
    
    func createNewMessageModel(
        fromUsername: String?,
        fromId: String?,
        toUsername: String?,
        toId: String?,
        message: String?,
        createdTime: String,
        messageId: String,
        instagramStoryMention: InstagramStoryMentionModel?,
        instagramStoryReply: InstagramStoryReplyModel?,
        instagramPost: InstagramPostModel?,
        imageAttachment: ImageAttachmentModel?,
        videoAttachment: VideoAttachmentModel?
    ) -> MessageModel? {
        if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil && message != nil {
            let fromUser = MetaUserModel(platform: "instagram", name: nil, email: nil, username: fromUsername, id: fromId!)
            let toUser = MetaUserModel(platform: "instagram", name: nil, email: nil, username: toUsername, id: toId!)
            print("returning message")
            
            let createdTime = Date().facebookStringToDate(fbString: createdTime)
            
            return MessageModel(id: messageId, message: message!, to: toUser, from: fromUser, createdTime: createdTime, instagramStoryMention: instagramStoryMention, instagramStoryReply: instagramStoryReply, instagramPost: instagramPost, imageAttachment: imageAttachment, videoAttachment: videoAttachment)
    
        }
        else {
            return nil
        }
    }
    
    func parseInstagramMessage(messageDataDict: [String: Any], messageId: String, createdTime: String, accessToken: String) async -> MessageModel? {
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
                    
                    let instagramStoryMention = parseInstagramStoryMention(messageId: messageId, messageDataDict: messageDataDict)
                    let instagramStoryReply = parseInstagramStoryReply(messageId: messageId, messageDataDict: messageDataDict)
                    let imageAttachment = parseImageAttachment(messageDataDict: messageDataDict)
                    let videoAttachment = parseVideoAttachment(messageDataDict: messageDataDict)
                    
                    if instagramStoryReply == nil && instagramStoryReply == nil && imageAttachment == nil && videoAttachment == nil && message == "" {
                        print("Calling /shares edge")
                        // Request /shares edge
                        let sharesDataURLString = "https://graph.facebook.com/v16.0/\(messageId)/shares?fields=link&access_token=\(accessToken)"
                        
                        print("message data url \(sharesDataURLString)")
                        
                        if let sharesResponse = await getRequest(urlString: sharesDataURLString) {
                            print("shares response \(sharesResponse)")
                            let instagramPost = await  parseInstagramPost(messageId: messageId, postDataDict: sharesResponse)
                            print(instagramPost, "instagram post")
                            return createNewMessageModel(fromUsername: fromUsername, fromId: fromId, toUsername: toUsername, toId: toId, message: message, createdTime: createdTime, messageId: messageId, instagramStoryMention: instagramStoryMention, instagramStoryReply: instagramStoryReply, instagramPost: instagramPost, imageAttachment: imageAttachment, videoAttachment: videoAttachment)
                        }
                    }
                    else {
                        return createNewMessageModel(fromUsername: fromUsername, fromId: fromId, toUsername: toUsername, toId: toId, message: message, createdTime: createdTime, messageId: messageId, instagramStoryMention: instagramStoryMention, instagramStoryReply: instagramStoryReply, instagramPost: nil, imageAttachment: imageAttachment, videoAttachment: videoAttachment)
                    }
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
        
        return nil
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
                        
                        return MessageModel(id: message_id, message: message!, to: toUser, from: fromUser, createdTime: createdTime, instagramStoryMention: nil, instagramStoryReply: nil, instagramPost: nil, imageAttachment: imageAttachment, videoAttachment: nil)
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func addConversationListeners(page: MetaPage) {
        print("Adding conversation listeners")
        
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
                    let sharePostUrl = data["share_post_url"] as? String
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
                                                
                                                // TODO: Make sure message does not already exist
                                                
                                                let existingMessage = self.fetchMessage(id: messageId!)
                                                
                                                if existingMessage == nil {
                                                    let newMessage = Message(
                                                        context: self.moc,
                                                        id: messageId!,
                                                        createdTime: messageDate,
                                                        message: messageText,
                                                        opened: NSNumber(value: false),
                                                        dayStarter: NSNumber(value: dayStarter),
                                                        conversation: conversation,
                                                        to: page.metaUser!,
                                                        from: conversation.correspondent!
                                                    )

                                                    if imageUrl != nil {
                                                        let newImageAttachment = ImageAttachment(
                                                            context: self.moc,
                                                            url: URL(string: imageUrl!),
                                                            message: newMessage,
                                                            id: messageId!
                                                        )
                                                        newMessage.imageAttachment = newImageAttachment
                                                    }
                                                    else {
                                                        if storyMentionUrl != nil {
                                                            // TODO: Get story ID
                                                            let newInstagramStoryMention = InstagramStoryMention(
                                                                context: self.moc,
                                                                id: messageId!,
                                                                cdnURL: URL(string: storyMentionUrl!),
                                                                message: newMessage
                                                            )
                                                            newMessage.instagramStoryMention = newInstagramStoryMention
                                                        }

                                                        else {
                                                            if storyReplyUrl != nil {
                                                                let newInstagramStoryReply = InstagramStoryReply(
                                                                    context: self.moc,
                                                                    id: messageId!,
                                                                    cdnURL: URL(string: storyReplyUrl!),
                                                                    message: newMessage
                                                                )
                                                                newMessage.instagramStoryReply = newInstagramStoryReply
                                                            }
                                                            
                                                            else {
                                                                if sharePostUrl != nil {
                                                                    let newInstagramPost = InstagramPost(
                                                                        context: self.moc,
                                                                        id: messageId!,
                                                                        cdnURL: URL(string: sharePostUrl!),
                                                                        mediaType: "photo", // TODO: Need to get content type from webhook
                                                                        message: newMessage
                                                                    )
                                                                }
                                                            }
                                                        }
                                                    }
                                                    
                                                    conversation.lastRefresh = Date()
                                                    
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
                            }
                            
                            // TODO: Of course facebook doesn't send the conversation ID with the webhook... this should work for now but may be slow. Try to come up with a more efficient way later
                            if !conversationFound && isDeleted != nil && !isDeleted! {
                                print("Initializing C")
                                self.initializePageInfo()
                            }
                        }
                    }
                }
            }
        }
    }
}
