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
                let existingPage = self.existingPages.first(where: { $0.id == pageModel.id })
                
                var page: MetaPage? = nil
                
                // Update some fields
                if existingPage != nil {
                    print("Existing page", existingPage)
                    existingPage!.category = pageModel.category
                    existingPage!.name = pageModel.name
                    existingPage!.accessToken = pageModel.accessToken
                    existingPage!.active = true
                    page = existingPage
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
                    page = newPage
                }
                
                Task {
                    await page!.getPageBusinessAccountId()
                    await page!.getProfilePicture()
                    self.updateSelectedPage {
                        var newConversations: [ConversationModel] = []
                        var platformCount = 0
                        for platform in messagingPlatforms {
                            Task {
                                let platformConversations = await self.getConversations(page: pageModel, platform: platform)
                                newConversations.append(contentsOf: platformConversations)
                                platformCount = platformCount + 1
                                if platformCount == messagingPlatforms.count {
                                    if page!.id == self.session.selectedPage?.id {
                                        print("Setting conv count w \(newConversations.count) \(page!.id) \(platformCount) \(messagingPlatforms.count)")
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
    
    func writeNewConversations() {
        DispatchQueue.main.async {
            print("CTU firing")
            if self.conversationsToUpdate == nil {
                self.session.conversationsToUpdate = 0
                self.session.loadingPageInformation = false
                return
            }
            
            for conversation in conversationsToUpdate! {
                let existingConversation = self.conversationsHook.first(where: {$0.id == conversation.id})
                let existingPage = self.existingPages.first(where: {$0.id == conversation.page.id})
                print("Existing conversation with id \(conversation.id) \(existingConversation)")
                // Update some fields...
                if existingConversation != nil {
                    existingConversation!.updatedTime = conversation.dateUpdated
                    existingConversation!.inDayRange = conversation.inDayRange
                    existingConversation!.metaPage = existingPage
                    print("Updating conversation", existingConversation)
                }
                
                // Create new instance
                else {
                    let newConversation = Conversation(context: self.moc)
                    newConversation.uid = UUID()
                    newConversation.id = conversation.id
                    newConversation.platform = conversation.platform
                    newConversation.updatedTime = conversation.dateUpdated
                    newConversation.inDayRange = conversation.inDayRange
                    newConversation.metaPage = existingPage
                    print("New conversation", newConversation)
                }
                
                conversation.lastRefresh = existingConversation?.lastRefresh
                
                print("CIDR", conversation.inDayRange)
                // TODO: Make sure loading goes to false when there are no conversations to get messages for
                if conversation.inDayRange && conversation.dateUpdated > existingConversation?.lastRefresh ?? Date(timeIntervalSince1970: 0) {
                    print("Getting new messages")
                    self.getNewMessages(conversation: conversation) { _ in}
                }
                else {
                    print("NO message update")
                    self.decrementConversationsToUpdate(pageID: conversation.page.id)
                }
            }
            do {
                try self.moc.save()
            } catch {
                print("Error saving A2 data: \(error.localizedDescription)")
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
        
            let conversation = self.conversationsHook.first(where: {$0.id == newMessageModels!.first!.conversation!.id})
            let page = self.existingPages.first(where: {$0.id == conversation?.metaPage!.id})
            
            if conversation == nil || page == nil {
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
                
                let toUser = self.updateOrCreateUser(user: newMessageModel.to)
                let fromUser = self.updateOrCreateUser(user: newMessageModel.from)
                
                newMessage.to = toUser
                newMessage.from = fromUser
                
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
    
}
