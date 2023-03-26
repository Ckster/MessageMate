//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import AVKit
import FBSDKLoginKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging


var userRegistry: [String: MetaUser] = [:]
var userConversationRegistry: [String: Conversation] = [:]


let monthMap: [Int: String] = [
    1: "January",
    2: "February",
    3: "March",
    4: "April",
    5: "May",
    6: "June",
    7: "July",
    8: "August",
    9: "September",
    10: "October",
    11: "November",
    12: "December"
]


enum MessagingPlatform: CaseIterable {
    case instagram
    case facebook
}

// TODO: Add support for post messages if possible
// TODO: Look into audio message if possible
// TODO: Add full screen for story mentions and replies
// TODO: Check on local notifcations waking app up from termination
// TODO: Do a check for minimum info before showing info


struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {

        if !self.session.loadingFacebookUserToken && self.session.facebookUserToken == nil {
            FacebookAuthenticateView().environmentObject(self.session)
        }
        else {
            ConversationsView().environmentObject(self.session)
        }
    }
}


struct ConversationsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State var loading: Bool = true
    @State var firstAppear: Bool = true
    @State var sortedConvervations: [Conversation]? = nil
    let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Messages").bold().font(Font.custom("Nunito-Bold", size: 30)).offset(x: 0).padding(.leading)
                    
                    if self.loading {
                        LottieView(name: "9844-loading-40-paperplane")
                            .onTapGesture(perform: {
                                if self.firstAppear {
                                    self.firstAppear = false
                                    Task {
                                        print("Starting B")
                                        await self.updatePages()
                                    }
                                }
                            })
                    }
                    
                    else {
                        Text("You have \(self.session.unreadMessages == 0 ? "no" : String(self.session.unreadMessages)) new \(self.session.unreadMessages != 1 ? "messages" : "message")").foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).padding(.leading).padding(.bottom)
                        
                        ScrollView {
                            if self.session.selectedPage != nil {
                                
                                PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                    self.loading = true
                                    Task {
                                        await self.updateConversations(page: self.session.selectedPage!)
                                    }
                                }
                                
                                if self.session.selectedPage!.conversations.count == 0 {
                                    Text("No conversations. Pull down to refresh.").font(Font.custom("Nunito-Black", size: 30))
                                }
                                
                                else {
                                    var sortedConversations = self.session.selectedPage!.conversations.sorted {$0.messages.last!.createdTime > $1.messages.last!.createdTime}
                                    ForEach(sortedConversations, id:\.self) { conversation in
                                        if conversation.messages.count > 0 {
                                            ConversationNavigationView(conversation: conversation, width: geometry.size.width, page: self.session.selectedPage!).environmentObject(self.session).onAppear(perform: {
                                                print("REFRESHING")
                                            })
                                        }
                                    }
                                }
                            }
                            
                            else {
                                PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                    self.loading = true
                                    Task {
                                        print("Starting A")
                                        await self.updatePages()
                                    }
                                }
                                Text("There are no business accounts linked to you. Add a business account to your Messenger account to see it here.").font(Font.custom("Nunito-Black", size: 30))
                            }
                        }.coordinateSpace(name: "pullToRefresh")
                    }
                }
            }
        }
        .accentColor(Color("aoBlue")) 
        .onChange(of: self.session.selectedPage ?? MetaPage(id: "", name: "", accessToken: "", category: ""), perform: {
            // TODO: Add de-listener here
            newPage in
            self.addConversationListeners(page: newPage)
        })
//        .onChange(of: scenePhase) {
//            newPhase in
//            print("PHASE", newPhase)
//            if newPhase == .active {
//                self.loading = true
//            Task {
//                print("Updating")
//                if self.session.selectedPage != nil {
//                    await self.updateConversations(page: self.session.selectedPage!)
//                }
//            }
//        }
//        }
//        .onAppear(perform: {
//            if self.session.selectedPage != nil {
//                print("Sorting")
//                self.session.selectedPage!.sortConversations()
//            }
//        })
    }
    
    func initializeConversationCollection(page: MetaPage, completion: @escaping () -> Void) {
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
    
    // TODO: Add an implement a listener remover
    func addConversationListeners(page: MetaPage) {
        
        self.initializeConversationCollection(page: page) {
            self.db.collection(Pages.name).document(page.id).collection(Pages.collections.CONVERSATIONS.name).addSnapshotListener {
                querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for conversations: \(error!)")
                    return
                }

                querySnapshot?.documentChanges.forEach { diff in
                    if (diff.type == .modified || diff.type == .added) {
                        // TODO: Add support for post share and video
                        
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
                            if self.session.selectedPage != nil {
                                if self.session.selectedPage!.businessAccountId ?? "" == pageId || self.session.selectedPage!.id == pageId {
                                    var conversationFound: Bool = false
                                    
                                    for conversation in self.session.selectedPage!.conversations {
                                        if conversation.correspondent != nil && conversation.correspondent!.id == senderId {
                                            conversationFound = true
                                            let messageDate = Date(timeIntervalSince1970: createdTime! / 1000)
                                            var imageAttachment: ImageAttachment? = nil
                                            var instagramStoryMention: InstagramStoryMention? = nil
                                            var instagramStoryReply: InstagramStoryReply? = nil
                                            
                                            let lastDate = Calendar.current.dateComponents([.month, .day], from: conversation.messages.last!.createdTime)
                                            let messageCompDate = Calendar.current.dateComponents([.month, .day], from: messageDate)
                                            let dayStarter = lastDate.month! != messageCompDate.month! || lastDate.day! != messageCompDate.day!
                                            
                                            let newMessage = Message(id: messageId!, message: messageText, to: page.pageUser!, from: conversation.correspondent!, dayStarter: dayStarter, createdTimeDate: messageDate)
            
                                            if isDeleted != nil && isDeleted! {
                                                let deleteAtIndex = conversation.messages.firstIndex(of: newMessage)
                                                if deleteAtIndex != nil {
                                                    Task {
                                                        await MainActor.run {
                                                            conversation.messages.remove(at: deleteAtIndex!)
                                                        }
                                                    }
                                                }
                                            }
            
                                            else {
                                                if imageUrl != nil {
                                                    imageAttachment = ImageAttachment(url: imageUrl!)
                                                }
                                                else {
                                                    if storyMentionUrl != nil {
                                                        // TODO: Get story ID
                                                        instagramStoryMention = InstagramStoryMention(id: "1", cdnUrl: storyMentionUrl!)
                                                    }
            
                                                    else {
                                                        if storyReplyUrl != nil {
                                                            instagramStoryReply = InstagramStoryReply(id: "1", cdnUrl: storyReplyUrl!)
                                                        }
                                                    }
                                                }
            
                                                newMessage.instagramStoryMention = instagramStoryMention
                                                newMessage.instagramStoryReply = instagramStoryReply
                                                newMessage.imageAttachment = imageAttachment
                                                
                                                // TODO: Need to also test if the message is old / outside of conversation pagination
                                                if !conversation.messages.contains(newMessage) {
                                                    print("Updating conversation \(senderId)")
                                                    var newMessages = conversation.messages
                                                    newMessages.append(newMessage)
                                                    Task {
                                                        await MainActor.run {
                                                            conversation.messages = sortMessages(messages: newMessages)
                                                            self.session.unreadMessages = self.session.unreadMessages + 1
                                                        }
                                                    }
                                                }
            
                                            }
                                        }
                                    }
                                    
                                    // TODO: Of course facebook doesn't send the conversation ID with the webhook... this should work for now but may be slow. Try to come up with a more efficient way later
                                    if !conversationFound {
                                        Task {
                                            await self.updateConversations(page: self.session.selectedPage!)
                                            self.session.unreadMessages = self.session.unreadMessages + 1
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
    
    //@MainActor
    func updatePages() async {
        var pagesLoaded = 0
        for page in self.session.availablePages {
            var newConversations: [Conversation] = []
            for platform in MessagingPlatform.allCases {
                let conversations = await self.getConversations(page: page, platform: platform)
                print(platform, conversations.count, "Count")
                newConversations = newConversations + conversations
            }
            
            page.conversations = newConversations
            
            // Do this asynchronously
            for conversation in page.conversations {
                print("Getting conversation")
                self.getMessages(page: page, conversation: conversation) {
                    conversationTuple in
                    let messages = conversationTuple.0
                    
                    // TODO: Unless there is info on opened status from API I have to assume message has been viewed or we keep some sort of on disk record
                    for message in messages {
                        message.opened = true
                    }
                    
                    let pagination = conversationTuple.1
                    if messages.count > 0 {
                        conversation.messages = messages.sorted { $0.createdTime < $1.createdTime }
                        conversation.pagination = pagination
                        let userList = conversation.updateCorrespondent()
                        if userList.count > 0 {
                            page.pageUser = userList[1]
                        }
                    }
                    
                    conversation.messagesInitialized = true
                    
                    var allConversationsLoaded: Bool = true
                    for conversation in page.conversations {
                        if !conversation.messagesInitialized {
                            allConversationsLoaded = false
                        }
                    }
                    
                    if allConversationsLoaded {
                        
                        // reset for the next reload
                        for conversation in page.conversations {
                            conversation.messagesInitialized = false
                        }
                        
                        pagesLoaded = pagesLoaded + 1
                        if pagesLoaded == self.session.availablePages.count {
                            self.loading = false
                        }
                        
                    }
                }
            }
        }
    }
    
    func updateConversations(page: MetaPage) async {
        var newConversations: [Conversation] = []
        // Do this asynchronously
        
        for conversation in page.conversations {
            self.getMessages(page: page, conversation: conversation) {
                conversationTuple in
                let messages = conversationTuple.0
                
                // TODO: Unless there is info on opened status from API I have to assume message has been viewed or we keep some sort of on disk record
                for message in messages {
                    message.opened = true
                }
                
                let pagination = conversationTuple.1
                if messages.count > 0 {
                    
                    Task {
                        await MainActor.run {
                            conversation.messages = messages
                            conversation.pagination = pagination
                            let userList = conversation.updateCorrespondent()
                            if userList.count > 0 {
                                page.pageUser = userList[1]
                            }
                        }
                    }
                    newConversations.append(conversation)
                }
                
                conversation.messagesInitialized = true
                
                var allConversationsLoaded: Bool = true
                for conversation in page.conversations {
                    if !conversation.messagesInitialized {
                        allConversationsLoaded = false
                    }
                }
                if allConversationsLoaded {
                    
                    // reset for the next reload
                    for conversation in page.conversations {
                        conversation.messagesInitialized = false
                    }
                    
                    page.conversations = newConversations
                    print("Done updating")
                    self.loading = false
                }
            }
        }
    }
    
    func getMessages(page: MetaPage, conversation: Conversation, cursor: String? = nil, completion: @escaping (([Message], PagingInfo?)) -> Void) {
        var urlString = "https://graph.facebook.com/v16.0/\(conversation.id)?fields=messages&access_token=\(page.accessToken)"
        
        if cursor != nil {
            urlString = urlString + "&after=\(String(describing: cursor))"
        }
        
        completionGetRequest(urlString: urlString) {
            jsonDataDict in
           
            let conversationData = jsonDataDict["messages"] as? [String: AnyObject]
            if conversationData != nil {
                
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
                    
                    if messageData != nil {
                        let messagesLen = messageData!.count
                        var indexCounter = 0
                        var newMessages: [Message] = []
                        
                        for message in messageData! {
                            print(message)
                            let id = message["id"] as? String
                            let createdTime = message["created_time"] as? String
                            
                            if id != nil && createdTime != nil {
                                let messageDataURLString = "https://graph.facebook.com/v16.0/\(id!)?fields=id,created_time,from,to,message,story,attachments,shares&access_token=\(page.accessToken)"
                            
                                completionGetRequest(urlString: messageDataURLString) {
                                    messageDataDict in
                                    if messageDataDict != nil {
                                        var message: Message?
                                        switch conversation.platform {
                                        case .instagram:
                                            message = parseInstagramMessage(messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!, previousMessage: newMessages.last)
                                        case .facebook:
                                            message = parseFacebookMessage(messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!, previousMessage: newMessages.last)
                                        }
                                        
                                        if message != nil {
                                            newMessages.append(message!)
                                        }
                                
                                        indexCounter = indexCounter + 1
                                        if indexCounter == messagesLen {

                                            // Start of the async get of profile pic url
                                            for user in userRegistry.values {
                                                if user.profilePicURL == nil {
                                                    user.getProfilePicture(access_token: page.accessToken)
                                                }
                                            }
                                            
                                            newMessages = newMessages.sorted { $0.createdTime < $1.createdTime }
                                            var lastDate: Foundation.DateComponents? = nil
                                            for message in newMessages {
                                                let createdTimeDate = Calendar.current.dateComponents([.month, .day], from: message.createdTime)
                                                var dayStarter = lastDate == nil
                                                if lastDate != nil {
                                                    dayStarter = lastDate!.month! != createdTimeDate.month! || lastDate!.day! != createdTimeDate.day!
                                                }
                                                lastDate = createdTimeDate
                                                message.dayStarter = dayStarter
                                            }
                                            completion((newMessages, pagingInfo))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
    
    func parseInstagramStoryMention(messageDataDict: [String: Any]) -> InstagramStoryMention? {
        var instagramStoryMention: InstagramStoryMention? = nil
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let mentionData = storyData!["mention"] as? [String: Any]
            if mentionData != nil {
                let id = mentionData!["id"] as? String
                let cdnUrl = mentionData!["link"] as? String
                if cdnUrl != nil {
                    print("updating instagram story")
                    instagramStoryMention = InstagramStoryMention(id: id, cdnUrl: cdnUrl!)
                }
            }
        }
        return instagramStoryMention
    }
    
    func parseInstagramStoryReply(messageDataDict: [String: Any]) -> InstagramStoryReply? {
        var instagramStoryReply: InstagramStoryReply? = nil
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let replyToData = storyData!["reply_to"] as? [String: Any]
            if replyToData != nil {
                let id = replyToData!["id"] as? String
                let cdnUrl = replyToData!["link"] as? String
                if cdnUrl != nil {
                    print("updating instagram story")
                    instagramStoryReply = InstagramStoryReply(id: id, cdnUrl: cdnUrl!)
                }
            }
        }
        return instagramStoryReply
    }
    
    func parseImageAttachment(messageDataDict: [String: Any]) -> ImageAttachment? {
        var imageAttachment: ImageAttachment? = nil
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["image_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            imageAttachment = ImageAttachment(url: url!)
                        }
                    }
                }
            }
        }
        return imageAttachment
    }
    
    func parseVideoAttachment(messageDataDict: [String: Any]) -> VideoAttachment? {
        var imageAttachment: VideoAttachment? = nil
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["video_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            imageAttachment = VideoAttachment(url: url!)
                        }
                    }
                }
            }
        }
        return imageAttachment
    }
    
    func parseInstagramMessage(messageDataDict: [String: Any], message_id: String, createdTime: String, previousMessage: Message? = nil) -> Message? {
        print(messageDataDict)
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

                    if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil {
                        let registeredUsernames = userRegistry.keys

                        var fromUser: MetaUser? = nil
                        if registeredUsernames.contains(fromId!) {
                            fromUser = userRegistry[fromId!]
                        }
                        else {
                            fromUser = MetaUser(id: fromId!, username: fromUsername!, email: nil, name: nil, platform: .instagram)
                            userRegistry[fromId!] = fromUser
                        }

                        var toUser: MetaUser? = nil
                        if registeredUsernames.contains(toId!) {
                            toUser = userRegistry[toId!]
                        }
                        else {
                            toUser = MetaUser(id: toId!, username: toUsername!, email: nil, name: nil, platform: .instagram)
                            userRegistry[toId!] = toUser
                        }
                        print("returning message")
                        
                        return Message(id: message_id, message: message!, to: toUser!, from: fromUser!, createdTimeString: createdTime, instagramStoryMention: instagramStoryMention, instagramStoryReply: instagramStoryReply, imageAttachment: imageAttachment, videoAttachment: videoAttachment)
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func parseFacebookMessage(messageDataDict: [String: Any], message_id: String, createdTime: String, previousMessage: Message? = nil) -> Message? {
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

                    if fromEmail != nil && fromId != nil && fromName != nil && toEmail != nil && toName != nil && toId != nil {
                        let registeredUsernames = userRegistry.keys

                        var fromUser: MetaUser? = nil
                        if registeredUsernames.contains(fromId!) {
                            fromUser = userRegistry[fromId!]
                        }
                        else {
                            fromUser = MetaUser(id: fromId!, username: nil, email: fromEmail, name: fromName, platform: .facebook)
                            userRegistry[fromId!] = fromUser
                        }

                        var toUser: MetaUser? = nil
                        if registeredUsernames.contains(toId!) {
                            toUser = userRegistry[toId!]
                        }
                        else {
                            toUser = MetaUser(id: toId!, username: nil, email: toEmail, name: toName, platform: .facebook)
                            userRegistry[toId!] = toUser
                        }
                    
                        return Message(id: message_id, message: message!, to: toUser!, from: fromUser!, createdTimeString: createdTime, imageAttachment: imageAttachment)
                    }
                    else {return nil}
                }
                else {return nil}
            }
            else {return nil}
        }
        else {return nil}
    }
    
    func getConversations(page: MetaPage, platform: MessagingPlatform) async -> [Conversation] {
        
        var urlString = "https://graph.facebook.com/v16.0/\(page.id)/conversations?"
        
        switch platform {
            case .facebook:
                break
            case .instagram:
                urlString = urlString + "platform=instagram"
        }
        
        urlString = urlString + "&access_token=\(page.accessToken)"
        
        var newConversations: [Conversation] = []
        let jsonDataDict = await getRequest(urlString: urlString)
        if jsonDataDict != nil {
            let conversations = jsonDataDict!["data"] as? [[String: AnyObject]]
            if conversations != nil {
                for conversation in conversations! {
                    let id = conversation["id"] as? String
                    let updatedTime = conversation["updated_time"] as? String
                    
                    if id != nil && updatedTime != nil {
                        newConversations.append(Conversation(id: id!, updatedTime: updatedTime!, page: page, pagination: nil, platform: platform))
                    }
                }
            }
        }
        return newConversations
    }
}


class PagingInfo {
    var beforeCursor: String?
    var afterCursor: String?
    
    init(beforeCursor: String?, afterCursor: String?) {
        self.beforeCursor = beforeCursor
        self.afterCursor = afterCursor
    }
}


struct ConversationNavigationView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var conversation: Conversation
    let width: CGFloat
    let page: MetaPage
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var correspondent: MetaUser
    @ObservedObject var pushNotificationState = PushNotificationState.shared
    @State var navigate: Bool = false
    
    init(conversation: Conversation, width: CGFloat, page: MetaPage) {
        self.conversation = conversation
        self.width = width
        self.page = page
        self.correspondent = conversation.correspondent!
    }
    
    var body: some View {
        VStack {
            let navTitle = conversation.correspondent?.name ?? conversation.correspondent?.username ?? conversation.correspondent?.email ?? ""
            
//            if navigate {
//                NavigationLink(
//                    destination: ConversationView(conversation: self.pushNotificationState.conversationToNavigateTo!, page: self.pushNotificationState.conversationToNavigateTo!.page), isActive: $navigate ) {
//                    EmptyView()
//                }
//            }
            
            NavigationLink(destination: ConversationView(conversation: conversation, page: page, navigate: self.$navigate).environmentObject(self.session)
                .navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem {
                        HStack {
                            HStack {
                                AsyncImage(url: URL(string: conversation.correspondent?.profilePicURL ?? "")) { image in image.resizable() } placeholder: { EmptyView() } .frame(width: 37.5, height: 37.5) .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 0.5) {
                                    Text(navTitle).font(Font.custom("Nunito-Bold", size: 18))
                                    switch conversation.correspondent?.platform {
                                    case .instagram:
                                        Image("instagram_logo").resizable().frame(width: 20.5, height: 20.5)
                                    case .facebook:
                                        Image("facebook_logo").resizable().frame(width: 20.5, height: 20.5)
                                    default:
                                        EmptyView()
                                    }
                                }.offset(y: -2)
                            }.frame(width: width * 0.60, alignment: .leading).padding().onTapGesture {
                                openProfile(correspondent: conversation.correspondent!)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }, isActive: $navigate
            ) {
                ZStack {
                    HStack {
                        AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("aoBlue")) } .frame(width: 55, height: 55).clipShape(Circle()).offset(y: conversation.messages.last!.message == "" ? -6 : 0)
                        
                        VStack(spacing: 0.5) {
                            HStack {
                                Text(navTitle).foregroundColor(self.colorScheme == .dark ? .white : .black).font(Font.custom("Nunito-Black", size: 22))
//                                Image(self.correspondent.platform == .instagram ? "instagram_logo" : "facebook_logo").resizable().frame(width: 15.5, height: 15.5)
                            }.frame(width: width * 0.55, alignment: .leading)
                        
                            HStack {
                                if conversation.messages.last!.instagramStoryMention != nil {
                                    Text("\(conversation.correspondent?.name ?? "") mentioned you in their story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).frame(width: width * 0.55, alignment: .leading)
                                }
                                else {
                                    
                                    if conversation.messages.last!.imageAttachment != nil {
                                        Text("\(conversation.correspondent?.name ?? "") sent you an image").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).frame(width: width * 0.55, alignment: .leading)
                                    }
                                    
                                    else {
                                        
                                        if conversation.messages.last!.instagramStoryReply != nil {
                                            Text("\(conversation.correspondent?.name ?? "") replied to your story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).frame(width: width * 0.55, alignment: .leading)
                                        }
                                        
                                        else {
                                            
                                            if conversation.messages.last!.videoAttachment != nil {
                                                Text("\(conversation.correspondent?.name ?? "") sent you a video").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).frame(width: width * 0.55, alignment: .leading)
                                            }
                                            
                                            else {
                                                Text((conversation.messages.last!).message).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 15)).frame(width: width * 0.55, alignment: .leading)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        let lastMessageIntervalString = self.makeTimeElapsedString(elapsedTime: conversation.messages.last!.createdTime.timeIntervalSinceNow)
                        Text(lastMessageIntervalString).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom("Nunito-Black", size: 10)).frame(width: width * 0.20)
                        
                    }
                    //.offset(x: 10)
                    
                    if !conversation.messages.last!.opened {
                        HStack(spacing: 0) {
                            Color("aoBlue").frame(width: width * 0.01, height: 75)
                            Color.offWhite.frame(width: width * 0.99, height: 75).opacity(0.10)
                        }
                    }
                }
            }
            
            HorizontalLine(color: .gray, height: 0.75)
            
        }.onReceive(self.pushNotificationState.$conversationToNavigateTo, perform: {
            conversation in
            if conversation != nil && conversation! == self.conversation.id {
                navigate = true
            }
        })
//        .onChange(of: self.openMessages) {
//            _ in
//            Task {
//                await MainActor.run {
//                    for message in self.conversation.messages {
//                        if !(message.opened) {
//                            message.opened = true
//                        }
//                    }
//                }
//            }
//        }
    }
    
    func makeTimeElapsedString(elapsedTime: Foundation.TimeInterval) -> String {
        let years = Int(elapsedTime * -1) / Int(86400 * 365)
        if years != 0 {
            return "\(years) \(years > 1 ? "years" : "year") ago"
        }
        let months = Int(elapsedTime * -1) / Int(86400 * 30)
        if months != 0 {
            return "\(months) \(months > 1 ? "months" : "month") ago"
        }
        let days = Int(elapsedTime * -1) / Int(86400)
        if days != 0 {
            return "\(days) \(days > 1 ? "days" : "day") ago"
        }
        let hours = Int(elapsedTime * -1) / Int(60 * 60)
        if hours != 0 {
            return "\(hours) \(hours > 1 ? "hours" : "hour") ago"
        }
        let minutes = Int(elapsedTime * -1) / Int(60)
        if minutes != 0 {
            return "\(minutes) \(minutes > 1 ? "minutes" : "minute") ago"
        }
        return "now"
    }
}


struct FacebookAuthenticateView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                Text("Please log in with Facebook to link your Messenger conversations").frame(height: geometry.size.height * 0.35, alignment: .center).padding()
                Button(action: {self.session.facebookLogin(authWorkflow: false)}) {
                    Image("facebook_login").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.80, height: geometry.size.height * 0.65, alignment: .center)
                }
            }
        }
    }
}


struct TextControlView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var showCouldNotGenerateResponse: Bool
    @Binding var messageSendError: String
    @Binding var typingMessage: String
    @ObservedObject var conversation: Conversation
    @State var loading: Bool = false
    
    let height: CGFloat
    let width: CGFloat
    let page: MetaPage
        
    
    var body: some View {
//        GeometryReader {
//            geometry in
            VStack {
                
                // Input text box / loading when message is being generated
                if self.loading {
                    LottieView(name: "97952-loading-animation-blue").frame(width: width, height: height * 0.10, alignment: .leading)
                }
                
                else {
                    DynamicHeightTextBox(typingMessage: self.$typingMessage, messageSendError: self.$messageSendError, height: height, width: width, conversation: conversation, page: page).frame(width: width * 0.925).environmentObject(self.session)
                }
                
           //     ZStack {
//                RoundedRectangle(cornerRadius: 16)
//                    .foregroundColor(Color.gray)
//                    .frame(width: width * 0.95, height: height * 0.07, alignment: .center).padding()
//                    .overlay(
                HStack(spacing: 2) {
                            
                            // Auto Generation buttons
                            AutoGenerateButton(buttonText: "Respond", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, loading: self.$loading, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse)
                                //.frame(width: width * 0.19, height: height * 0.07)
                            
                            AutoGenerateButton(buttonText: "Sell", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, loading: self.$loading, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse)
                                //.frame(width: width * 0.19, height: height * 0.07)
                            
                            AutoGenerateButton(buttonText: "Yes", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, loading: self.$loading, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse)
                               // .frame(width: width * 0.19, height: height * 0.07)
                            
                            AutoGenerateButton(buttonText: "No", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, loading: self.$loading, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse)
                                //.frame(width: width * 0.19, height: height * 0.07)
                            
                            DeleteTypingTextButton(width: self.width, height: self.height, typingText: self.$typingMessage)
                                //.frame(width: width * 0.19, height: height * 0.07)
                            
                }.padding(.top).padding(.bottom)
                            //.frame(width: width * 0.90, height: height * 0.06)
                 //   )
              //  }
            }
            .padding(.bottom)
            .padding(.top)
       // }
    }
}


struct MessageDateHeaderView: View {
    let msg: Message
    let width: CGFloat
    let dateString: String
    
    init (msg: Message, width: CGFloat) {
        self.msg = msg
        self.width = width
                
        let dates = Calendar.current.dateComponents([.hour, .minute, .month, .day], from: msg.createdTime)
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let yesterday = Calendar.current.dateComponents([.month, .day], from: Date.yesterday)
        var dateString = "\(monthMap[dates.month!]!) \(dates.day!) at \(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")"
        if dates.month! == today.month! && dates.day! == today.day! {
            dateString = "Today"
        }
        if dates.month! == yesterday.month! && dates.day! == yesterday.day! {
            dateString = "Yesterday"
        }
        self.dateString = dateString
    }
    
    var body: some View {
        Text(self.dateString)
            .font(.system(size: 10))
            .foregroundColor(.gray)
            .frame(width: width, alignment: .center)
    }
}


extension Date {
    static var yesterday: Date { return Date().dayBefore }
    static var tomorrow:  Date { return Date().dayAfter }
    var dayBefore: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: noon)!
    }
    var dayAfter: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: noon)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }
    var isLastDayOfMonth: Bool {
        return dayAfter.month != month
    }
}


struct MessageThreadView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var typingMessage: String
    @ObservedObject var conversation: Conversation
    
    let height: CGFloat
    let width: CGFloat
    let page: MetaPage
    
    var body: some View {
        ScrollView {
            ScrollViewReader {
                value in
                VStack {
                    ForEach(conversation.messages, id: \.self.uid) { msg in
                        if msg.dayStarter != nil && msg.dayStarter! {
                            MessageDateHeaderView(msg: msg, width: width)
                        }
                        MessageView(width: width, currentMessage: msg, conversation: conversation, page: page).id(msg.id)
                            .onAppear(perform: {
                            if !msg.opened {
                                msg.opened = true
                                if self.session.unreadMessages > 0 {
                                    self.session.unreadMessages = self.session.unreadMessages - 1
                                }
                            }
                        })
                    }
                }.onChange(of: typingMessage) { _ in
                    value.scrollTo(conversation.messages.last?.id)
                }.onChange(of: conversation.messages) { _ in
                    value.scrollTo(conversation.messages.last?.id)
                }.onAppear(perform: {
                    value.scrollTo(conversation.messages.last?.id)
                })
            }
        }
    }
}


struct ConversationView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var conversation: Conversation
    
    @FocusState var messageIsFocused: Bool
    
    @State var typingMessage: String = ""
    @State var placeholder: Bool = true
    @State var textEditorHeight : CGFloat = 100
    @State var loading: Bool = false
    @State var showCouldNotGenerateResponse: Bool = false
    @State var messageSendError: String = ""
    @State var offset = CGSize.zero
    
    @Binding var navigate: Bool
    
   // @Binding var openMessages: Bool
    
    var maxHeight : CGFloat = 250
    
    let page: MetaPage

    init(conversation: Conversation, page: MetaPage, navigate: Binding<Bool>) {
        self.conversation = conversation
        self.page = page
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UINavigationBar.appearance().standardAppearance = appearance
        _navigate = navigate
    }
    
    var body: some View {
        GeometryReader {
            geometry in
            
            ZStack {
                VStack {
                    
                    MessageThreadView(typingMessage: self.$typingMessage, conversation: self.conversation, height: geometry.size.height, width: geometry.size.width, page: page).onTapGesture {
                        self.messageIsFocused = false
                    }
                    
                    TextControlView(showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse, messageSendError: self.$messageSendError, typingMessage: self.$typingMessage, conversation: self.conversation, height: geometry.size.height, width: geometry.size.width, page: page).focused($messageIsFocused).onDisappear(perform: {
                        print("ON DISAPPEAR")
                        self.session.selectedPage!.sortConversations()
                    }).environmentObject(self.session)
                    
                }
                .opacity(self.session.videoPlayerUrl != nil || self.session.fullScreenImageUrlString != nil ? 0.10 : 1)
                .transition(AnyTransition.scale.animation(.easeInOut(duration: 0.50)))
                
                if self.session.videoPlayerUrl != nil {
                    let player = AVPlayer(url: self.session.videoPlayerUrl!)
                    VStack {
                        Image(systemName: "xmark").font(.system(size: 30)).frame(width: geometry.size.width, alignment: .leading).onTapGesture {
                            self.session.videoPlayerUrl = nil
                            player.pause()
                        }.padding(.bottom).padding(.leading)

                        VideoPlayer(player: player)
                            .frame(height: 1000).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.90, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .onAppear(perform: {
                                player.play()
                            })
                    }
                    .transition(AnyTransition.scale.animation(.easeInOut(duration: 0.50)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { _ in
                                if abs(offset.height) > 100 {
                                    player.pause()
                                    offset = .zero
                                    self.session.videoPlayerUrl = nil
                                } else {
                                    offset = .zero
                                }
                            }
                    )
                }
                
                if self.session.fullScreenImageUrlString != nil {
                    VStack {
                        Image(systemName: "xmark").font(.system(size: 30)).frame(width: geometry.size.width, alignment: .leading).onTapGesture {
                            self.session.fullScreenImageUrlString = nil
                        }.padding(.bottom).padding(.leading)

                        AsyncImage(url: URL(string: self.session.fullScreenImageUrlString!)) {
                            image in
                            image.resizable()
                        } placeholder: {
                            LottieView(name: "97952-loading-animation-blue").frame(width: 50, height: 50, alignment: .leading)
                        }
                            .frame(height: 1000).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.90, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .onTapGesture(perform: {
                                self.session.fullScreenImageUrlString = nil
                            })
                           
                    }
                    .transition(AnyTransition.scale.animation(.easeInOut(duration: 0.50)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { _ in
                                if abs(offset.height) > 100 {
                                    offset = .zero
                                    self.session.fullScreenImageUrlString = nil
                                } else {
                                    offset = .zero
                                }
                            }
                    )
                }

                if self.showCouldNotGenerateResponse {
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundColor(Color.blue)
                        .frame(width: geometry.size.width * 0.85, height: 150, alignment: .center).padding()
                        .overlay(
                            VStack {
                                Text("Could not generate a response").frame(width: geometry.size.width * 0.85, height: 150, alignment: .center)
                            }
                        )
                }

                if self.messageSendError != "" {
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundColor(Color.blue)
                        .frame(width: geometry.size.width * 0.85, height: 150, alignment: .center)
                        .overlay(
                            Text(self.messageSendError).frame(width: geometry.size.width * 0.85, height: 150, alignment: .center)
                        ).padding(.leading)
                }
                
            }
        }
//        .onAppear(perform: {
//            self.openMessages.toggle()
//        })
        .onDisappear(perform: {
            self.navigate = false
        })
    }
    
    func rectReader(_ binding: Binding<CGFloat>, _ space: CoordinateSpace = .global) -> some View {
        GeometryReader { (geometry) -> Color in
            let rect = geometry.frame(in: space)
            Task {
                await MainActor.run {
                    binding.wrappedValue = rect.midY
                }
            }
            return .clear
        }
    }
}

struct AutoGenerateButton: View {
    let buttonText: String
    let width: CGFloat
    let height: CGFloat
    let conversationId: String
    let pageAccessToken: String
    let pageName: String
    let accountId: String
    @Binding var loading: Bool
    @Binding var typingText: String
    @Binding var showCouldNotGenerateResponse: Bool
    
    var body: some View {
        Button(action: {
            self.loading = true
            generateResponse(responseType: self.buttonText.lowercased(), conversationId: conversationId, pageAccessToken: pageAccessToken, pageName: pageName, accountId: accountId) {
                message in
                
                if message != "" {
                    self.typingText = message
                    self.loading = false
                }
                else {
                    self.loading = false
                    self.showCouldNotGenerateResponse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.showCouldNotGenerateResponse = false
                    }
                }
            }
        }) {
            Text(self.buttonText).font(.system(size: 13)).bold()
                .frame(width: width * 0.185, height: height * 0.07)
        }
        .buttonStyle(SimpleButtonStyle(width: width, height: height))
   }
}


extension LinearGradient {
    init(_ colors: Color...) {
        self.init(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}


struct SimpleButtonStyle: ButtonStyle {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Self.Configuration) -> some View {
        if colorScheme == .light {
            configuration.label
                .background(
                    Group {
                        if configuration.isPressed {
                            Circle()
                                .fill(Color.offWhite)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 4)
                                        .blur(radius: 4)
                                        .offset(x: 2, y: 2)
                                        .mask(Circle().fill(LinearGradient(Color.black, Color.clear)))
                                        .frame(width: width * 0.165, height: width * 0.165)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 8)
                                        .blur(radius: 4)
                                        .offset(x: -2, y: -2)
                                        .mask(Circle().fill(LinearGradient(Color.clear, Color.black)))
                                        .frame(width: width * 0.165, height: width * 0.165)
                                )
                                .frame(width: width * 0.165, height: width * 0.165)
                        } else {
                            Circle()
                                .fill(Color.offWhite)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 10, y: 10)
                                .shadow(color: Color.white.opacity(0.7), radius: 10, x: -5, y: -5)
                                .frame(width: width * 0.165, height: width * 0.165)
                               // .cornerRadius(6)
                        }
                    }
                )
        }
        else {
            configuration.label
                .contentShape(
                    Circle()
                )
                .background(
                    DarkBackground(isHighlighted: configuration.isPressed, shape: Circle(), width: width, height: height)
                )
                
        }
    }
}


extension Color {
    static let offWhite = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)
    static let darkStart = Color(red: 50 / 255, green: 60 / 255, blue: 65 / 255)
    static let darkEnd = Color(red: 25 / 255, green: 25 / 255, blue: 30 / 255)
}


struct DarkBackground<S: Shape>: View {
    var isHighlighted: Bool
    var shape: S
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            if isHighlighted {
                shape
                    .fill(Color.darkEnd)
                    .shadow(color: Color.darkStart, radius: 5, x: 1.5, y: 1.5)
                    .shadow(color: Color.darkEnd, radius: 5, x: -1.5, y: -1.5)
                    .frame(width: width * 0.165, height: width * 0.165)

            } else {
                shape
                    .fill(Color.darkEnd)
                    .shadow(color: Color.darkStart, radius: 5, x: -1.5, y: -1.5)
                    .shadow(color: Color.darkEnd, radius: 5, x: 1.5, y: 1.5)
                    .frame(width: width * 0.165, height: width * 0.165)
            }
        }
    }
}


//struct DarkButtonStyle: ButtonStyle {
//    func makeBody(configuration: Self.Configuration) -> some View {
//        configuration.label
//            .padding(30)
//            .contentShape(Circle())
//            .background(
//                DarkBackground(isHighlighted: configuration.isPressed, shape: Circle())
//            )
//    }
//}


struct DeleteTypingTextButton: View {
    let width: CGFloat
    let height: CGFloat
    @Binding var typingText: String
    
    var body: some View {
        Button(action: {
            self.typingText = ""
        }) {
            Image(systemName: "trash")
                //.foregroundColor(.white)
                .frame(width: width * 0.175, height: height * 0.07)
             //.background(Color.red)
            }.buttonStyle(SimpleButtonStyle(width: width, height: height))
   }
}




func generateResponse(responseType: String, conversationId: String, pageAccessToken: String, pageName: String, accountId: String, completion: @escaping (String) -> Void) {
    let urlString = "https://us-central1-messagemate-2d9af.cloudfunctions.net/generate_response"
    let currentUser = Auth.auth().currentUser
    
    currentUser?.getIDTokenForcingRefresh(true) { idToken, error in
        if let error = error {
            // TODO: Tell user there was an issue and to try again
            print(error, "ERROR")
            return
        }
        
        let header: [String: String] = [
            "authorization": idToken!,
            "responseType": responseType,
            "conversationId": conversationId,
            "pageAccessToken": pageAccessToken,
            "pageName": pageName,
            "pageId": accountId
        ]
        
        Task {
            let data = await getRequest(urlString: urlString, header: header)
            if data != nil {
                completion(data!["message"] as? String ?? "ERROR")
            }
        }
        
        
    }
}


struct DynamicHeightTextBox: View {
    @EnvironmentObject var session: SessionStore
    @Binding var typingMessage: String
    @Binding var messageSendError: String
    @State var textEditorHeight : CGFloat = 100
    @Environment(\.colorScheme) var colorScheme
    
    var maxHeight : CGFloat = 10000
    let height: CGFloat
    let width: CGFloat
    let conversation: Conversation
    let page: MetaPage
    
    var body: some View {
            ZStack(alignment: .leading) {
                
                // Send message button
                Button(
                    action: {
                        self.sendMessage(message: self.typingMessage, to: conversation.correspondent!) {
                            response in
                            self.messageSendError = (response["error"] as? [String: Any])?["message"] as? String ?? ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                  self.messageSendError = ""
                            }
                        }
                    }
                ) {
                    Image(systemName: "paperplane.circle.fill")
//                        .resizable()
//                        .scaledToFit()
                        .font(.system(size: 35))
                        .position(x: width * 0.85, y: 10)
                        .frame(height: 20).foregroundColor(Color("aoBlue"))
                      //  .clipShape(Circle())
                }
                
                Text(typingMessage)
                    .lineLimit(5)
                    .font(.system(.body))
                    .foregroundColor(.clear)
                    .padding(15)
                    .background(GeometryReader {
                        Color.clear.preference(key: ViewHeightKey.self,
                                               value: $0.frame(in: .local).size.height)
                    })
                    .frame(width: width * 0.80)
                
                TextEditor(text: $typingMessage)
                    .font(.system(.body))
                    .padding(7)
                    .frame(height: min(textEditorHeight, maxHeight))
                    .background(self.colorScheme == .dark ? Color.black : Color.white)
                    .frame(width: width * 0.80)
               
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.gray, lineWidth: 1)
            )
            .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
        }
    
    
    func sendMessage(message: String, to: MetaUser, completion: @escaping ([String: Any]) -> Void) {
        /// API Reference: https://developers.facebook.com/docs/messenger-platform/reference/send-api/
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)/messages?access_token=\(page.accessToken)"
        let data: [String: Any] = ["recipient": ["id": to.id], "message": ["text": message]]
        let jsonData = try? JSONSerialization.data(withJSONObject: data)
        
        if jsonData != nil {
            print("Message Data not Nil")
            postRequest(urlString: urlString, data: jsonData!) {
                sentMessageData in
                let messageId = sentMessageData["message_id"] as? String
                
                if messageId != nil {
//                    let conversationIndex = self.session.selectedPage!.conversations.firstIndex(of: self.conversation)
//                    var conversation: Conversation? = nil
//                    if conversationIndex != nil {
//                        conversation = self.session.selectedPage!.conversations[conversationIndex!]
//                    }
                    
                   // if conversation != nil {
                    for conversation in self.session.selectedPage!.conversations {
                        if conversation.correspondent != nil && conversation.correspondent!.id == self.conversation.correspondent!.id {
                            
                            let createdDate = Date(timeIntervalSince1970: NSDate().timeIntervalSince1970)
                            print(Date().dateToFacebookString(date: createdDate), "sent", NSDate().timeIntervalSince1970)
                            let lastDate = Calendar.current.dateComponents([.month, .day], from: self.conversation.messages.last!.createdTime)
                            let messageDate = Calendar.current.dateComponents([.month, .day], from: createdDate)
                            
                            let dayStarter = lastDate.month! != messageDate.month! || lastDate.day! != messageDate.day!
                            
                            var newMesssage = Message(id: messageId!, message: message, to: conversation.correspondent!, from: page.pageUser!, dayStarter: dayStarter, createdTimeDate: createdDate)
                            
                            newMesssage.opened = true
                            
                            var newMessages = conversation.messages
                            newMessages.append(newMesssage)
                            
                            Task {
                                await MainActor.run {
                                    
                                    conversation.messages = sortMessages(messages: newMessages)
                                    print("rearranged")
                                    
                                    self.typingMessage = ""
                                }
                            }
                            
                        }}
                    
                    //}
                }
                completion(sentMessageData)
            }
        }
        else {
            completion(["error": ["message": "Could not encode message data"]])
        }
    }
}

// TODO: Add an alert if you don't have permission to send message
struct MessageView : View {
    @EnvironmentObject var session: SessionStore
    let width: CGFloat
    var currentMessage: Message
    @ObservedObject var conversation: Conversation
    let page: MetaPage
    @ObservedObject var correspondent: MetaUser
    
    init(width: CGFloat, currentMessage: Message, conversation: Conversation, page: MetaPage) {
        self.conversation = conversation
        self.width = width
        self.page = page
        self.currentMessage = currentMessage
        self.correspondent = conversation.correspondent!
    }
    
    var body: some View {
        let isCurrentUser = page.businessAccountId == currentMessage.from.id || page.id == currentMessage.from.id
        let dates = Calendar.current.dateComponents([.hour, .minute], from: currentMessage.createdTime)
        if !isCurrentUser {
            VStack(spacing: 1) {
                HStack {
                    AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("aoBlue")) } .frame(width: 25, height: 25, alignment: .bottom) .clipShape(Circle()).padding(.leading).onTapGesture {
                            openProfile(correspondent: correspondent)
                    }
                    MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser)
                }.frame(width: width * 0.875, alignment: .leading).padding(.trailing).offset(x: -20)
                
                Text("\(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")")
                    .frame(width: width * 0.875, alignment: .leading).padding(.trailing)
                    .font(Font.custom("Nunito-Black", size: 9))
                    .foregroundColor(.gray)
            }
        }
        else {
            VStack(spacing: 1) {
                MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser)
                    .frame(width: width * 0.875, alignment: .trailing).padding(.leading).padding(.trailing)
                Text("\(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")")
                    .frame(width: width * 0.875, alignment: .trailing).padding(.leading).padding(.trailing)
                    .font(Font.custom("Nunito-Black", size: 9))
                    .foregroundColor(.gray)
            }
        }
    }
}


func openProfile(correspondent: MetaUser) {
    var hook = ""
    switch correspondent.platform {
        case .instagram:
            hook = "instagram://user?username=\(correspondent.username!)"
        case .facebook:
            hook = "fb://profile/\(correspondent.email!)"
    }
    let hookUrl = URL(string: hook)
    if hookUrl != nil {
        if UIApplication.shared.canOpenURL(hookUrl!) {
            UIApplication.shared.open(hookUrl!)
        }
    }
}


struct InstagramStoryReplyView: View {
    let contentMessage: Message
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Rectangle().frame(width: 5).foregroundColor(.gray).cornerRadius(10)
                VStack(alignment: .leading) {
                    Text("Replied to your story").font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    if contentMessage.instagramStoryReply!.cdnUrl != "" {
                        AsyncImage(url: URL(string: contentMessage.instagramStoryReply!.cdnUrl ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("aoBlue")) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    else {
                        Text("")
                            .padding(10)
                            .foregroundColor(isCurrentUser ? Color.white : Color.black)
                            .background(isCurrentUser ? Color.blue : Color(UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)))
                            .cornerRadius(10)
                    }
                }
            }
            Text(contentMessage.message)
                .padding(10)
                .foregroundColor(isCurrentUser ? Color.white : Color.black)
                .background(isCurrentUser ? Color.blue : Color(UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)))
                .cornerRadius(10)
        }
    }
}


struct InstagramStoryMentionView: View {
    let contentMessage: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            Rectangle().frame(width: 5).foregroundColor(.gray).cornerRadius(10)
            VStack(alignment: .leading) {
                Text("Mentioned you in their story")
                    .foregroundColor(.gray).font(.system(size: 10))
                
                if contentMessage.instagramStoryMention!.cdnUrl != "" {
                    AsyncImage(url: URL(string: contentMessage.instagramStoryMention!.cdnUrl ?? "")) { image in image.resizable() } placeholder: { LottieView(name: "97952-loading-animation-blue").frame(width: 50, height: 50, alignment: .leading) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                else {
                    Text("")
                        .padding(10)
                        .foregroundColor(isCurrentUser ? Color.white : Color.black)
                        .background(isCurrentUser ? Color.blue : Color(UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)))
                        .cornerRadius(10)
                }
            }
        }
    }
}


struct ImageAttachmentView: View {
    @EnvironmentObject var session: SessionStore
    let contentMessage: Message
    
    var body: some View {
        AsyncImage(url: URL(string: contentMessage.imageAttachment!.url ?? "")) {
            image in
            image.resizable()
        } placeholder: {
            LottieView(name: "97952-loading-animation-blue").frame(width: 50, height: 50, alignment: .leading)
        }.frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                self.session.fullScreenImageUrlString = contentMessage.imageAttachment!.url
            }
    }
}


struct VideoAttachmentView: View {
    @EnvironmentObject var session: SessionStore
    let contentMessage: Message
    @State var playing: Bool = false
    @State var fullScreen: Bool = false
    @State var offset = CGSize.zero
        
    var body: some View {
        let url = URL(string: contentMessage.videoAttachment!.url ?? "")
        
        if url != nil {
            let player = AVPlayer(url: url!)
            VideoPlayer(player: player) {
                Image(systemName: "play.fill").font(.system(size: 30))
            }
                //.frame(height: 400)
                .frame(width: 150, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture {
                    self.session.videoPlayerUrl = url
            }
        }
        else {
            Text("Could not load video")
        }
    }
}


struct MessageBlurbView: View {
    @EnvironmentObject var session: SessionStore
    let contentMessage: Message
    let isCurrentUser: Bool

    var body: some View {
        if contentMessage.instagramStoryMention != nil {
            InstagramStoryMentionView(contentMessage: contentMessage, isCurrentUser: isCurrentUser)
        }
        else {
            if contentMessage.imageAttachment != nil {
                ImageAttachmentView(contentMessage: contentMessage)
            }
            else {
                if contentMessage.instagramStoryReply != nil {
                    InstagramStoryReplyView(contentMessage: contentMessage, isCurrentUser: isCurrentUser)
                }
                else {
                    
                    if contentMessage.videoAttachment != nil {
                        VideoAttachmentView(contentMessage: contentMessage)
                    }
                    
                    else {
                        Text(contentMessage.message)
                            .padding(10)
                            .foregroundColor(isCurrentUser ? Color.white : Color.black)
                            .background(isCurrentUser ? Color("aoBlue") : Color.offWhite)
                            .cornerRadius(10)
                            .font(Font.custom("Nunito-Black", size: 17))
                    }
                }
            }
        }
    }
}

struct PullToRefresh: View {

    var coordinateSpaceName: String
    var onRefresh: () -> Void

    @State var needRefresh: Bool = false

    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > 80) {
                Spacer()
                    .onAppear {
                        let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                        impactMed.impactOccurred()
                        needRefresh = true
                    }
            } else if (geo.frame(in: .named(coordinateSpaceName)).maxY < 10) {
                Spacer()
                    .onAppear {
                        if needRefresh {
                            needRefresh = false
                            onRefresh()
                        }
                    }
            }
            HStack {
                Spacer()
                VStack {
                    if needRefresh {
                        ProgressView()
                    }
                }
                Spacer()
            }
        }.padding(.top, -50)
    }
}

struct TextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var placeholder: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {

        let myTextView = UITextView()
        myTextView.delegate = context.coordinator
        myTextView.font = UIFont(name: "HelveticaNeue", size: 17)
        myTextView.isScrollEnabled = true
        myTextView.isEditable = true
        myTextView.isUserInteractionEnabled = true
        myTextView.backgroundColor = UIColor(white: 0.0, alpha: 0.05)

        return myTextView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = self.placeholder && (self.text == "") ? "Message..." : text
    }

    class Coordinator : NSObject, UITextViewDelegate {

        var parent: TextView

        init(_ uiTextView: TextView) {
            self.parent = uiTextView
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            self.parent.text = textView.text
        }
    }
}



struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}


class InstagramStoryMention: Hashable, Equatable {
    let id: String?
    let cdnUrl: String
    
    init (id: String?, cdnUrl: String) {
        self.id = id
        self.cdnUrl = cdnUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.cdnUrl)
    }

    static func == (lhs: InstagramStoryMention, rhs: InstagramStoryMention) -> Bool {
        return lhs.cdnUrl == rhs.cdnUrl
    }
    
}


class InstagramStoryReply: Hashable, Equatable {
    let id: String?
    let cdnUrl: String
    
    init (id: String?, cdnUrl: String) {
        self.id = id
        self.cdnUrl = cdnUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.cdnUrl)
    }

    static func == (lhs: InstagramStoryReply, rhs: InstagramStoryReply) -> Bool {
        return lhs.cdnUrl == rhs.cdnUrl
    }
    
}


class ImageAttachment: Hashable, Equatable {
//    let height: Int
//    let width: Int
    let url: String

    init (url: String) {
        self.url = url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.url)
    }

    static func == (lhs: ImageAttachment, rhs: ImageAttachment) -> Bool {
        return lhs.url == rhs.url
    }

}


class VideoAttachment: Hashable, Equatable {
//    let height: Int
//    let width: Int
    let url: String

    init (url: String) {
        self.url = url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.url)
    }

    static func == (lhs: VideoAttachment, rhs: VideoAttachment) -> Bool {
        return lhs.url == rhs.url
    }

}


class Message: Hashable, Equatable {
    let id: String
    let uid: UUID = UUID()
    let message: String
    let to: MetaUser
    let from: MetaUser
    let createdTime: Date
    var opened: Bool = false
    var instagramStoryMention: InstagramStoryMention?
    var instagramStoryReply: InstagramStoryReply?
    var imageAttachment: ImageAttachment?
    var videoAttachment: VideoAttachment?
    var dayStarter: Bool? = nil
    
    init (id: String, message: String, to: MetaUser, from: MetaUser, dayStarter: Bool? = nil, createdTimeString: String? = nil, createdTimeDate: Date? = nil, instagramStoryMention: InstagramStoryMention? = nil, instagramStoryReply: InstagramStoryReply? = nil, imageAttachment: ImageAttachment? = nil, videoAttachment: VideoAttachment? = nil) {
        self.id = id
        self.message = message
        self.to = to
        self.from = from
        if createdTimeString != nil {
            self.createdTime = Date().facebookStringToDate(fbString: createdTimeString!)
        }
        else {
            self.createdTime = createdTimeDate!
        }
        self.instagramStoryMention = instagramStoryMention
        self.instagramStoryReply = instagramStoryReply
        self.imageAttachment = imageAttachment
        self.videoAttachment = videoAttachment
        self.dayStarter = dayStarter
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

class Conversation: Hashable, Equatable, ObservableObject {
    let id: String
    let updatedTime: Date?
    let page: MetaPage
    var correspondent: MetaUser? = nil
    var pagination: PagingInfo?
    var messagesInitialized: Bool = false
    let platform: MessagingPlatform
    @Published var messages: [Message] = []
    
    init(id: String, updatedTime: String, page: MetaPage, pagination: PagingInfo?, platform: MessagingPlatform) {
        self.id = id
        self.page = page
        self.updatedTime = Date().facebookStringToDate(fbString: updatedTime)
        self.pagination = pagination
        self.platform = platform
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }
    
    func updateCorrespondent() -> [MetaUser] {
        var rList: [MetaUser] = []
        for message in self.messages {
            if message.from.id != (platform == .instagram ? page.businessAccountId : page.id) {
                self.correspondent = message.from
                userConversationRegistry[message.from.id] = self
                
                rList = [message.from, message.to]
                break
            }
            else {
                self.correspondent = message.to
                userConversationRegistry[message.to.id] = self
                
                rList = [message.to, message.from]
                break
            }
        }
        return rList
    }
}


func sortMessages(messages: [Message]) -> [Message] {
    return messages.sorted {$0.createdTime < $1.createdTime}
}



class MetaPage: Hashable, Equatable, ObservableObject {
    let id: String
    let name: String
    let accessToken: String
    let category: String
    @Published var conversations: [Conversation] = []
    var businessAccountId: String? = nil
    var pageUser: MetaUser? = nil
    var photoURL: String?
    
    init(id: String, name: String, accessToken: String, category: String, photoURL: String? = nil, businessAccountId: String? = nil) {
        self.id = id
        self.name = name
        self.accessToken = accessToken
        self.category = category
        self.photoURL = photoURL
        self.businessAccountId = businessAccountId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: MetaPage, rhs: MetaPage) -> Bool {
        return lhs.id == rhs.id
    }
    
    func sortConversations() {
        Task {
            await MainActor.run {
                self.conversations = self.conversations.sorted {$0.messages.last!.createdTime > $1.messages.last!.createdTime}
            }
        }
    }
    
    //@MainActor
    func getProfilePicture(accountId: String) async {
        let urlString = "https://graph.facebook.com/v16.0/\(accountId)/picture?redirect=0"

        let profileData = await getRequest(urlString: urlString)
        if profileData != nil {
            let data = profileData!["data"] as? [String: AnyObject]
            if data != nil {
                let profilePicURL = data!["url"] as? String
                self.photoURL = profilePicURL?.replacingOccurrences(of: "\\", with: "")
            }
        }
    }
    
    func getPageBusinessAccountId(page: MetaPage) async {
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)?fields=instagram_business_account&access_token=\(page.accessToken)"
        
        let jsonDataDict = await getRequest(urlString: urlString)
        var returnId: String? = nil
        if jsonDataDict != nil {
            let instaData = jsonDataDict!["instagram_business_account"] as? [String: String]
            if instaData != nil {
                let id = instaData!["id"]
                if id != nil {
                    returnId = id!
                }
            }
        }
        self.businessAccountId = returnId
    }
    
}


class MetaUser: Hashable, Equatable, ObservableObject {
    let id: String
    let username: String?
    let email: String?
    let name: String?
    let platform: MessagingPlatform
    @Published var profilePicURL: String? = nil
    
    init(id: String, username: String?, email: String?, name: String?, platform: MessagingPlatform) {
        self.id = id
        self.username = username
        self.email = email
        self.name = name
        self.platform = platform
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: MetaUser, rhs: MetaUser) -> Bool {
        return lhs.id == rhs.id
    }
    
    func getProfilePicture(access_token: String) {
        let urlString = "https://graph.facebook.com/v16.0/\(self.id)?access_token=\(access_token)"
        completionGetRequest(urlString: urlString) {
            profileData in
            
            let profilePicURL = profileData["profile_pic"] as? String
            Task {
                await MainActor.run {
                    self.profilePicURL = profilePicURL?.replacingOccurrences(of: "\\", with: "")
                }
            }
        }
    }
}


func getRequest(urlString: String, header: [String: String]? = nil) async -> [String: AnyObject]? {
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    
    if header != nil {
        for key in header!.keys {
            request.setValue(header![key]!, forHTTPHeaderField: key)
        }
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
            return jsonDataDict
        }
        else {
            return nil
        }
      }
      catch {
          return nil
      }
}


func completionGetRequest(urlString: String, completion: @escaping ([String: AnyObject]) -> Void) {
    let url = URL(string: urlString)!
    let request = URLRequest(url: url)
    
    let dataTask = URLSession.shared.dataTask(with: request) {(data, response, error) in
        if let error = error {
            print("Request error:", error)
            return
        }
        
        guard let data = data else {
            print("Couldn't get data")
            return
        }

        do {
            if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                completion(jsonDataDict)
            }
            else {
                print("Couldn't deserialize data")
            }
        }
        
        catch let error as NSError {
            print(error)
        }
        
    }
    dataTask.resume()
}


func postRequest(urlString: String, data: Data, completion: @escaping ([String: AnyObject]) -> Void) {
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    request.httpBody = data
    
    let dataTask = URLSession.shared.dataTask(with: request) {(data, response, error) in
        if let error = error {
            print("Request error:", error)
            return
        }
        
        guard let data = data else {
            print("Couldn't get data")
            return
        }

        do {
            if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                completion(jsonDataDict)
            }
            else {
                print("Couldn't deserialize data")
            }
        }
        
        catch let error as NSError {
            print(error)
        }
        
    }
    dataTask.resume()
}


func initializePage(page: MetaPage) {
    let db = Firestore.firestore()
    
    let pageDoc = db.collection(Pages.name).document(page.id)
    pageDoc.getDocument() {
        doc, error in
        if error == nil && doc != nil {
            if !doc!.exists {
                db.collection(Pages.name).document(page.id).setData(
                    [
                        Pages.fields.INSTAGRAM_ID: page.businessAccountId,
                        Pages.fields.STATIC_PROMPT: "",
                        Pages.fields.NAME: page.name,
                        Pages.fields.APNS_TOKENS: [Messaging.messaging().fcmToken ?? ""]
                    ]
                ) {
                    _ in
                }
            }
            else {
                doc!.reference.updateData([
                    Pages.fields.INSTAGRAM_ID: page.businessAccountId,
                    Pages.fields.NAME: page.name,
                    Pages.fields.APNS_TOKENS: FieldValue.arrayUnion([Messaging.messaging().fcmToken ?? ""])
                ])
            }
        }
    }
}


extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}

extension Date {
    func facebookStringToDate(fbString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.date(from: fbString) ?? Date()
    }
    
    func dateToFacebookString(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.string(from: date) ?? ""
    }
}
