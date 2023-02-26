//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FBSDKLoginKit
import FirebaseFirestore
import FirebaseAuth


var userRegistry: [String: MetaUser] = [:]


struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        
        if self.session.facebookUserToken == nil {
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
    @State var loading: Bool = true
    @State var firstAppear: Bool = true
    let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Inbox").bold().font(.system(size: 30)).offset(x: 0).padding(.leading).padding(.bottom)
                    
                    if self.loading {
                        LottieView(name: "9844-loading-40-paperplane")
                    }
                    else {
                        ScrollView {
                            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                self.loading = true
                                Task {
                                    await self.updatePages()
                                }
                            }
                            
                            if self.session.selectedPage != nil {
                                if self.session.selectedPage!.conversations.count == 0 {
                                    Text("No conversations. Pull down to refresh")
                                }
                                else {
                                    ForEach(self.session.selectedPage!.conversations, id:\.self) { conversation in
                                        if conversation.messages.count > 0 {
                                            ConversationNavigationView(conversation: conversation, width: geometry.size.width, page: self.session.selectedPage!)
                                        }
                                    }
                                }
                            }
                            
                            else {
                                Text("There are no business accounts linked to you. Add a business account to your Messenger account to see it here.")
                            }
                            
                        }.coordinateSpace(name: "pullToRefresh")
                    }
                }
            }
        }
        .onAppear(perform: {
            if self.firstAppear {
                self.firstAppear = false
                Task {
                    await self.updatePages()
                }
            }
        })
        .onChange(of: self.session.selectedPage ?? MetaPage(id: "", name: "", accessToken: "", category: ""), perform: {
            newPage in
            if newPage.businessAccountId != nil {
                self.addConversationListeners(page: newPage)
            }
        })
    }
    
    // TODO: Add an implement a listener remover
    func addConversationListeners(page: MetaPage) {
        if page.businessAccountId != nil {
            self.db.collection(Pages.name).document(page.businessAccountId!).collection(Pages.collections.CONVERSATIONS.name).addSnapshotListener {
                querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for conversations: \(error!)")
                    return
                }

                querySnapshot?.documentChanges.forEach { diff in
                    if (diff.type == .modified) {
                        let data = diff.document.data()
                        self.updateConversation(correspondentId: diff.document.documentID)
                    }
                }
            }
        }
    }
    
    @MainActor
    func updateConversation(correspondentId: String) {
        if self.session.selectedPage != nil {
            for conversation in self.session.selectedPage!.conversations {
                if conversation.correspondent != nil && conversation.correspondent!.id == correspondentId{
                    Task {
                        let newConversationInfo = await self.getMessages(page: self.session.selectedPage!, conversation: conversation, cursor: conversation.pagination?.afterCursor)
                        conversation.messages = conversation.messages + newConversationInfo.0
                        conversation.pagination = newConversationInfo.1
                    }
                }
            }
        }
    }
    
    @MainActor
    func updatePages() async {
        let pages = await self.getPages()
        for page in pages {
            let conversations = await self.getConversations(page: page)
            var newConversations: [Conversation] = []
            for conversation in conversations {
                let conversationTuple = await self.getMessages(page: page, conversation: conversation)
                let messages = conversationTuple.0
                let pagination = conversationTuple.1
                if messages.count > 0 {
                    conversation.messages = messages.sorted { $0.createdTime < $1.createdTime }
                    conversation.pagination = pagination
                    let userList = conversation.updateCorrespondent()
                    if userList.count > 0 {
                        page.pageUser = userList[1]
                        self.initializePageConversations(page: page, correspondentId: conversation.correspondent!.id)
                        newConversations.append(conversation)
                    }
                }
            
                if conversation == conversations.last {
                    page.conversations = newConversations
                    if page == pages.last {
                        self.session.availablePages = pages
                        if self.session.selectedPage == nil && self.session.availablePages.count > 0 {
                            self.session.selectedPage = self.session.availablePages[0]
                        }
                        
                        self.loading = false
                    }
                }
            }
        }
    }
    
    // TODO: Clean this up
    func initializePageConversations(page: MetaPage, correspondentId: String) {
        if page.businessAccountId != nil {
            let pageDoc = self.db.collection(Pages.name).document(page.businessAccountId!)
            pageDoc.getDocument() {
                doc, error in
                if error == nil && doc != nil {
                    if doc!.exists {
                        let pageDocument = Pages(pageId: page.businessAccountId!)
                        let pageConversations = self.db.collection("\(pageDocument.documentPath)/\(Pages.collections.CONVERSATIONS.name)").document(correspondentId)
                        
                        pageConversations.getDocument {
                            doc, error in
                            if error == nil && doc != nil {
                                if doc!.exists {
                                    // TODO: Do some more granular checks
                                }
                                
                                // Initialize the page
                                else {
                                    let pageFields = Pages.collections.CONVERSATIONS.documents.fields
                                    pageConversations.setData([
                                        pageFields.TRIGGER: nil
                                    ])
                                }
                            }
                        }
                    }
                    else {
                        self.db.collection(Pages.name).document(page.businessAccountId!).setData([:]) {
                            _ in
                            let pageDocument = Pages(pageId: page.businessAccountId!)
                            let pageConversations = self.db.collection("\(pageDocument.documentPath)/\(Pages.collections.CONVERSATIONS.name)").document(correspondentId)
                            
                            pageConversations.getDocument {
                                doc, error in
                                if error == nil && doc != nil {
                                    if doc!.exists {
                                        // TODO: Do some more granular checks
                                    }
                                    
                                    // Initialize the page
                                    else {
                                        let pageFields = Pages.collections.CONVERSATIONS.documents.fields
                                        pageConversations.setData([
                                            pageFields.TRIGGER: nil
                                        ])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getMessages(page: MetaPage, conversation: Conversation, cursor: String? = nil) async -> ([Message], PagingInfo?) {
        var urlString = "https://graph.facebook.com/v16.0/\(conversation.id)?fields=messages&access_token=\(page.accessToken)"
        if cursor != nil {
            urlString = urlString + "&after=\(String(describing: cursor))"
        }
        
        var conversationInfo: ([Message], PagingInfo?) = ([], nil)
        let jsonDataDict = await getRequest(urlString: urlString)
        if jsonDataDict != nil {
            let conversationData = jsonDataDict!["messages"] as? [String: AnyObject]
    
            if conversationData != nil {
                var pagingInfo: PagingInfo? = nil
                let pointerData = conversationData!["paging"] as? [String: AnyObject]
                if pointerData != nil {
                    let cursorData = pointerData!["cursor"] as? [String: String]
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
                        let id = message["id"] as? String
                        let createdTime = message["created_time"] as? String
                        
                        if id != nil {
                            let messageDataURLString = "https://graph.facebook.com/v9.0/\(id!)?fields=id,created_time,from,to,message&access_token=\(page.accessToken)"
                            
                            let messageDataDict = await getRequest(urlString: messageDataURLString)
                            if messageDataDict != nil {
                                let fromDict = messageDataDict!["from"] as? [String: AnyObject]
                                let toDictList = messageDataDict!["to"] as? [String: AnyObject]
                                let message = messageDataDict!["message"] as? String
                                
                                if toDictList != nil {
                                    let toDict = toDictList!["data"] as? [[String: AnyObject]]
    
                                    // TODO: Support for group chats? Probably not
                                    if toDict!.count == 1 {
                                        if fromDict != nil && toDict != nil && message != nil {
                                            let fromUsername = fromDict!["username"] as? String
                                            let fromId = fromDict!["id"] as? String
                                            let toUsername = toDict![0]["username"] as? String
                                            let toId = toDict![0]["id"] as? String
                            
                                            if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil {
                                                let registeredUsernames = userRegistry.keys
                                                
                                                var fromUser: MetaUser? = nil
                                                if registeredUsernames.contains(fromId!) {
                                                    fromUser = userRegistry[fromId!]
                                                }
                                                else {
                                                    fromUser = MetaUser(id: fromId!, username: fromUsername!)
                                                    userRegistry[fromId!] = fromUser
                                                }
                                                
                                                var toUser: MetaUser? = nil
                                                if registeredUsernames.contains(toId!) {
                                                    toUser = userRegistry[toId!]
                                                }
                                                else {
                                                    toUser = MetaUser(id: toId!, username: toUsername!)
                                                    userRegistry[toId!] = toUser
                                                }
                                                
                                                newMessages.append(Message(id: id!, message: message!, to: toUser!, from: fromUser!, createdTime: createdTime!))
                                                
                                            }
                                        }
                                    }
                                }
                            
                                indexCounter = indexCounter + 1
                                if indexCounter == messagesLen {
                                    
                                    // Start of the async get of profile pic url
                                    for user in userRegistry.values {
                                        if user.profilePicURL == nil {
                                            await user.getProfilePicture(access_token: page.accessToken)
                                        }
                                    }
                                    conversationInfo = (newMessages, pagingInfo)
                                }
                            }
                        }
                    }
                }
            }
        }
        return conversationInfo
    }
    
    func getConversations(page: MetaPage) async -> [Conversation] {
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)/conversations?platform=instagram&access_token=\(page.accessToken)"
        
        var newConversations: [Conversation] = []
        let jsonDataDict = await getRequest(urlString: urlString)
        if jsonDataDict != nil {
            let conversations = jsonDataDict!["data"] as? [[String: AnyObject]]
            if conversations != nil {
                for conversation in conversations! {
                    let id = conversation["id"] as? String
                    let updatedTime = conversation["updated_time"] as? String
                    
                    if id != nil && updatedTime != nil {
                        newConversations.append(Conversation(id: id!, updatedTime: updatedTime!, page: page, pagination: nil))
                    }
                }
            }
        }
        return newConversations
    }
    
    @MainActor
    func getPages() async -> [MetaPage] {
        var newPagesReturn: [MetaPage] = []
        if self.session.facebookUserToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.session.facebookUserToken!)"
            
            let jsonDataDict = await getRequest(urlString: urlString)
            if jsonDataDict != nil {
                let pages = jsonDataDict!["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var newPages: [MetaPage] = []
                    let pageCount = pages!.count
                    var pageIndex = 0
                    
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if pageAccessToken != nil && category != nil && name != nil && id != nil {
                            let newPage = MetaPage(id: id!, name: name!, accessToken: pageAccessToken!, category: category!)
                            let busAccountId = await self.getPageBusinessAccountId(page: newPage)
                            
                            if busAccountId != nil {
                                newPage.businessAccountId = busAccountId!
                                await newPage.getProfilePicture(accountId: id!)
                              
                                newPages.append(newPage)
                                if pageIndex == pageCount {
                                    newPagesReturn = newPages
                                }
                            }
                        }
                    }
                }
            }
        }
        return newPagesReturn
    }
    
    func getPageBusinessAccountId(page: MetaPage) async -> String? {
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
        return returnId
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
    var conversation: Conversation
    let width: CGFloat
    let page: MetaPage
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var correspondent: MetaUser
    
    init(conversation: Conversation, width: CGFloat, page: MetaPage) {
        self.conversation = conversation
        self.width = width
        self.page = page
        self.correspondent = conversation.correspondent!
    }
    
    var body: some View {
        VStack {
            NavigationLink(destination: ConversationView(conversation: conversation, page: page).navigationTitle(conversation.correspondent!.username)) {
                HStack {
                    AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle") } .frame(width: 55, height: 55) .clipShape(Circle()).offset(y: conversation.messages.last!.message == "" ? -6 : 0)
                    VStack {
                        Text(conversation.correspondent!.username).foregroundColor(self.colorScheme == .dark ? .white : .black).font(.system(size: 23)).frame(width: width * 0.85, alignment: .leading)
                        HStack {
                            Text((conversation.messages.last!).message).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(.system(size: 23)).frame(width: width * 0.65, alignment: .leading)
                            Spacer() 
                            //Color.clear.frame(width: width * 0.20, height: 1, alignment: .leading)
                        }
                    }
                }
            }.navigationBarTitleDisplayMode(.inline).navigationTitle(" ")
            HorizontalLine(color: .gray, height: 0.75)
        }.padding(.leading).offset(x: width * 0.03)
    }
}


struct FacebookAuthenticateView: View {
    @EnvironmentObject var session: SessionStore
    let loginManager = LoginManager()
    let db = Firestore.firestore()
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                Text("Please log in with Facebook to link your Messenger conversations").frame(height: geometry.size.height * 0.35, alignment: .center).padding()
                Button(action: {self.facebookLogin(authWorkflow: false)}) {
                    Image("facebook_login").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.80, height: geometry.size.height * 0.65, alignment: .center)
                }
            }
        }
    }
    
    func facebookLogin(authWorkflow: Bool) {
        self.loginManager.logIn(permissions: ["instagram_basic", "instagram_manage_messages", "pages_manage_metadata"], from: nil) { (loginResult, error) in
            if error == nil {
                if loginResult?.isCancelled == false {
                    let userAccessToken = AccessToken.current!.tokenString
                    self.session.facebookUserToken = userAccessToken
                    
                    // Add to the database
                    if self.session.user.uid != nil {
                        self.db.collection(Users.name).document(self.session.user.uid!).updateData([Users.fields.FACEBOOK_USER_TOKEN: userAccessToken])
                    }
                }
            }
            else {
                print(error)
                // TODO: There was an error signing in, show something to the user
            }
        }
    }
}


struct ConversationView: View {
    @ObservedObject var conversation: Conversation
    let page: MetaPage
    @State var typingMessage: String = ""
    @State var placeholder: Bool = true
    @State var scrollDown: Bool = false
    @State var textEditorHeight : CGFloat = 100
    @FocusState var messageIsFocused: Bool
    var maxHeight : CGFloat = 250
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme

    init(conversation: Conversation, page: MetaPage) {
        self.conversation = conversation
        self.page = page
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UINavigationBar.appearance().standardAppearance = appearance
    }
    
    // TODO: Make sure message goes away when send button is pressed
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                
                // The message thread
                ScrollView {
                    ScrollViewReader {
                        value in
                        VStack {
                            ForEach(conversation.messages, id: \.self.id) { msg in
                                MessageView(width: geometry.size.width, currentMessage: msg, conversation: conversation, page: page).id(msg.id)
                            }
                        }.onChange(of: scrollDown) { _ in
                            value.scrollTo(conversation.messages.last?.id)
                        }.onChange(of: typingMessage) { _ in
                            value.scrollTo(conversation.messages.last?.id)
                        }.onAppear(perform: {
                            value.scrollTo(conversation.messages.last?.id)
                        })
                    }
                }.onTapGesture {
                    self.messageIsFocused = false
                    self.placeholder = true
                }
                    
                VStack {
                    
                    // Input text box
                    DynamicHeightTextBox(typingMessage: self.$typingMessage).frame(width: geometry.size.width * 0.9, alignment: .leading).padding(.trailing).offset(x: -5).focused($messageIsFocused)
                    
                    // Auto Generation buttons and send button
                    HStack(spacing: 2) {
                        Button(action: {self.generateResponse(responseType: "respond")}) {
                            Text("Respond")
                                .foregroundColor(.white)
                                //.frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.07)
                                .background(Color.blue)
                                .clipShape(Rectangle()).cornerRadius(6)
                        }
                            
                        Button(action: {self.generateResponse(responseType: "sell")}) {
                            Text("Sell")
                                .foregroundColor(.white)
                                //.frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.07)
                                .background(Color.blue)
                                .clipShape(Rectangle()).cornerRadius(6)
                        }
                        
                        Button(action: {self.generateResponse(responseType: "yes")}) {
                            Text("Yes")
                                .foregroundColor(.white)
                                //.frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.07)
                                .background(Color.blue)
                                .clipShape(Rectangle()).cornerRadius(6)
                        }
                        
                        Button(action: {self.generateResponse(responseType: "no")}) {
                            Text("No")
                                .foregroundColor(.white)
                                //.frame(width: geometry.size.width * 0.18, height: geometry.size.height * 0.07)
                                .background(Color.blue)
                                .clipShape(Rectangle()).cornerRadius(6)
                        }
                        
                        // Send message button
                        Button(
                            action: {sendMessage(message: self.typingMessage, to: conversation.correspondent!)}
                        ) {
                           Image(systemName: "paperplane.circle.fill").font(.system(size: 35))
                       }.frame(width: geometry.size.width * 0.18, alignment: .leading)
                    }.frame(width: geometry.size.width)
                }
                    .padding(.bottom)
                    .padding(.top)

            }
        }
        .onAppear(perform: {
            self.session.showMenu = false
        }).onDisappear(perform: {
            self.session.showMenu = true
        })
    }
    
    func sendMessage(message: String, to: MetaUser) {
        /// API Reference: https://developers.facebook.com/docs/messenger-platform/reference/send-api/
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)/messages?access_token=\(page.accessToken)"
        let data: [String: Any] = ["recipient": ["id": to.id], "message": ["text": message]]
        let jsonData = try? JSONSerialization.data(withJSONObject: data)
        
        if jsonData != nil {
            postRequest(urlString: urlString, data: jsonData!) {
                sentMessageData in
                let messageId = sentMessageData["message_id"] as? String
                
                if messageId != nil {
                    DispatchQueue.main.async {
                        let createdDate = Date().dateToFacebookString(date: Date(timeIntervalSince1970: NSDate().timeIntervalSince1970))
                        self.conversation.messages.append(Message(id: messageId!, message: message, to: to, from: page.pageUser!, createdTime: createdDate))
                        self.typingMessage = ""
                    }
                }
            }
        }
        else {
            // TODO: Show the user there was an issue
        }
    }
    
    @MainActor
    func generateResponse(responseType: String) {
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
                "conversationId": self.conversation.id,
                "pageAccessToken": self.page.accessToken,
                "pageName": self.page.name,
                "pageId": self.page.id
            ]
            
            Task {
                let data = await getRequest(urlString: urlString, header: header)
                if data != nil {
                    self.typingMessage = data!["message"] as? String ?? "ERROR"
                }
            }
        }

    }

    func rectReader(_ binding: Binding<CGFloat>, _ space: CoordinateSpace = .global) -> some View {
        GeometryReader { (geometry) -> Color in
            let rect = geometry.frame(in: space)
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                binding.wrappedValue = rect.midY
            }
            return .clear
        }
    }
}

struct AutoGenerateButton: View {
    let buttonText: String
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Button(action: {}) {
            Text(self.buttonText)
                .foregroundColor(.white).frame(width: width * 0.18, height: height * 0.07)
             .background(Color.blue)
             .clipShape(Rectangle()).cornerRadius(6)
        }
    }
}

struct DynamicHeightTextBox: View {
    @Binding var typingMessage: String
    @State var textEditorHeight : CGFloat = 100
    @Environment(\.colorScheme) var colorScheme
    var maxHeight : CGFloat = 1000
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(typingMessage)
                .lineLimit(5)
                .font(.system(.body))
                .foregroundColor(.clear)
                .padding(15)
                .background(GeometryReader {
                    Color.clear.preference(key: ViewHeightKey.self,
                                           value: $0.frame(in: .local).size.height)
                })

            TextEditor(text: $typingMessage)
                .font(.system(.body))
                .padding(7)
                .frame(height: min(textEditorHeight, maxHeight))
                .background(self.colorScheme == .dark ? Color.black : Color.white)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.gray, lineWidth: 1)
        )
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
    }
    
}


struct MessageView : View {
    let width: CGFloat
    var currentMessage: Message
    var conversation: Conversation
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
        let isCurrentUser = page.businessAccountId == currentMessage.from.id
        if !isCurrentUser {
            HStack {
                AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle") } .frame(width: 45, height: 45) .clipShape(Circle())
                MessageBlurbView(contentMessage: currentMessage.message,
                                   isCurrentUser: isCurrentUser)
            }.frame(width: width * 0.875, alignment: .leading).padding(.trailing).offset(x: -7)
        }
        else {
            MessageBlurbView(contentMessage: currentMessage.message,
                             isCurrentUser: isCurrentUser).frame(width: width * 0.875, alignment: .trailing).padding(.leading).padding(.trailing)
        }
    }
}

struct MessageBlurbView: View {
    var contentMessage: String
    var isCurrentUser: Bool

    var body: some View {
        Text(contentMessage)
            .padding(10)
            .foregroundColor(isCurrentUser ? Color.white : Color.black)
            .background(isCurrentUser ? Color.blue : Color(UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)))
            .cornerRadius(10)
    }
}

struct PullToRefresh: View {

    var coordinateSpaceName: String
    var onRefresh: () -> Void

    @State var needRefresh: Bool = false

    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > 50) {
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


struct MessagingUI: View {
    @State private var textEditorHeight : CGFloat = 100
    @State private var text = "Testing text. Hit a few returns to see what happens"

    private var maxHeight : CGFloat = 250

    var body: some View {
        VStack {
            VStack {
                Text("Messages")
                Spacer()
            }
            Divider()
            HStack {
                ZStack(alignment: .leading) {
                    Text(text)
                        .font(.system(.body))
                        .foregroundColor(.clear)
                        .padding(14)
                        .background(GeometryReader {
                            Color.clear.preference(key: ViewHeightKey.self,
                                                   value: $0.frame(in: .local).size.height)
                        })

                    TextEditor(text: $text)
                        .font(.system(.body))
                        .padding(6)
                        .frame(height: min(textEditorHeight, maxHeight))
                        .background(Color.black)
                }
                .padding(20)
                Button(action: {}) {
                    Image(systemName: "plus.circle")
                        .imageScale(.large)
                        .foregroundColor(.primary)
                        .font(.title)
                }.padding(15).foregroundColor(.primary)
            }.onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
        }
    }
}


struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}


class Message: Hashable, Equatable {
    let id: String
    let message: String
    let to: MetaUser
    let from: MetaUser
    let createdTime: Date
    
    init (id: String, message: String, to: MetaUser, from: MetaUser, createdTime: String) {
        self.id = id
        self.message = message
        self.to = to
        self.from = from
        self.createdTime = Date().facebookStringToDate(fbString: createdTime)
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
    @Published var messages: [Message] = []
    
    init(id: String, updatedTime: String, page: MetaPage, pagination: PagingInfo?) {
        self.id = id
        self.page = page
        self.updatedTime = Date().facebookStringToDate(fbString: updatedTime)
        self.pagination = pagination
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
            if message.from.id != page.businessAccountId {
                self.correspondent = message.from
                rList = [message.from, message.to]
                break
            }
            else {
                self.correspondent = message.to
                rList = [message.to, message.from]
                break
            }
        }
        return rList
    }
}

class MetaPage: Hashable, Equatable {
    let id: String
    let name: String
    let accessToken: String
    let category: String
    var conversations: [Conversation] = []
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
        self.conversations = self.conversations.sorted {$0.messages.last!.createdTime > $1.messages.last!.createdTime}
    }
    
    @MainActor
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
}


class MetaUser: Hashable, Equatable, ObservableObject {
    let id: String
    let username: String
    @Published var profilePicURL: String? = nil
    
    init(id: String, username: String) {
        self.id = id
        self.username = username
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: MetaUser, rhs: MetaUser) -> Bool {
        return lhs.id == rhs.id
    }
    
    @MainActor
    func getProfilePicture(access_token: String) async {
        let urlString = "https://graph.facebook.com/v16.0/\(self.id)?access_token=\(access_token)"
        
        let profileData = await getRequest(urlString: urlString)
        if profileData != nil {
            let profilePicURL = profileData!["profile_pic"] as? String
            self.profilePicURL = profilePicURL?.replacingOccurrences(of: "\\", with: "")
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
    
//    {(data, response, error) in
//        if let error = error {
//            print("Request error:", error)
//            return
//        }
//
//        guard let data = data else {
//            print("Couldn't get data")
//            return
//        }
//
//        do {
//            if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
//                completion(jsonDataDict)
//            }
//            else {
//                print("Couldn't deserialize data")
//            }
//        }
//
//        catch let error as NSError {
//            print(error)
//        }
//
//    }
    
    
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
