//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FBSDKLoginKit
import FirebaseFirestore


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
    @State var pages: [Page] = []
    @State var loading: Bool = true
    @State var firstAppear: Bool = true
    @State var selectedPageIndex: Int = 0
    
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
                                self.updatePages()
                            }
                            
                            if self.pages.count > 0 {
                                if self.pages[self.selectedPageIndex].conversations.count == 0 {
                                    Text("No conversations. Pull down to refresh")
                                }
                                else {
                                    ForEach(self.pages[self.selectedPageIndex].conversations, id:\.self) { conversation in
                                        if conversation.messages.count > 0 {
                                            ConversationNavigationView(conversation: conversation, width: geometry.size.width, page: self.pages[self.selectedPageIndex])
                                        }
                                        else {
                                            Text("ZERO")
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
                print("ON_APPEAR")
                self.firstAppear = false
                self.updatePages()
            }
        })
    }
    
    func updatePages() {
        self.getPages() { pages in
            for page in pages {
                self.getConversations(page: page) {
                    conversations in
                    var newConversations: [Conversation] = []
                    
                    for conversation in conversations {
                        self.getMessages(page: page, conversation: conversation) {
                            messages in
                            if messages.count > 0 {
                                conversation.messages = messages.sorted { $0.createdTime < $1.createdTime }
                                let userList = conversation.updateCorrespondent()
                                page.pageUser = userList[1]
                                newConversations.append(conversation)
                            }
                        
                            if conversation == conversations.last {
                                page.conversations = newConversations
                                if page == pages.last {
                                    print("Updating")
                                    for conversation in pages[0].conversations {
                                        print(conversation.correspondent!.username)
                                    }
                                    self.pages = pages
                                    self.loading = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getMessages(page: Page, conversation: Conversation, completion: @escaping ([Message]) -> Void) {
        // TODO: Only look for details on 20 most recent messages
        
        let urlString = "https://graph.facebook.com/v16.0/\(conversation.id)?fields=messages&access_token=\(page.accessToken)"
        getRequest(urlString: urlString) {
            jsonDataDict in
            let messagePointers = jsonDataDict["messages"] as? [String: AnyObject]
            if messagePointers != nil {
                let messagePointerData = messagePointers!["data"] as? [[String: AnyObject]]
                if messagePointerData != nil {
                    let messagePointerLen = messagePointerData!.count
                    var indexCounter = 0
                    var newMessages: [Message] = []
                    
                    for messagePointer in messagePointerData! {
                        let id = messagePointer["id"] as? String
                        let createdTime = messagePointer["created_time"] as? String
                        
                        if id != nil {
                            let messageDataURLString = "https://graph.facebook.com/v9.0/\(id!)?fields=id,created_time,from,to,message&access_token=\(page.accessToken)"
                            getRequest(urlString: messageDataURLString) {
                                messageDataDict in
                            
                                let fromDict = messageDataDict["from"] as? [String: AnyObject]
                                let toDictList = messageDataDict["to"] as? [String: AnyObject]
                                let message = messageDataDict["message"] as? String
                                
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
                                if indexCounter == messagePointerLen {
                                    
                                    // Start of the async get of profile pic url
                                    for user in userRegistry.values {
                                        if user.profilePicURL == nil {
                                            user.getProfilePicture(access_token: page.accessToken)
                                        }
                                    }
                                    completion(newMessages)
                                }
                            }
                        }
                    }
                    
                    if messagePointerLen == 0 {
                        completion([])
                    }
                }
            }
        }
    }
    
    func getConversations(page: Page, completion: @escaping ([Conversation]) -> Void) {
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)/conversations?platform=instagram&access_token=\(page.accessToken)"
        getRequest(urlString: urlString) {
            jsonDataDict in
            let conversations = jsonDataDict["data"] as? [[String: AnyObject]]
            var newConversations: [Conversation] = []
            if conversations != nil {
                for conversation in conversations! {
                    let id = conversation["id"] as? String
                    let updatedTime = conversation["updated_time"] as? String
                    
                    if id != nil && updatedTime != nil {
                        newConversations.append(Conversation(id: id!, updatedTime: updatedTime!, page: page))
                    }
                }
                completion(newConversations)
            }
            else {
                completion([])
            }
        }
    }
    
    func getPages(completion: @escaping ([Page]) -> Void) {
        if self.session.facebookUserToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.session.facebookUserToken!)"
            getRequest(urlString: urlString) {
                jsonDataDict in
                NSLog("Received data:\n\(jsonDataDict))")
                let pages = jsonDataDict["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var newPages: [Page] = []
                    let pageCount = pages!.count
                    var pageIndex = 0
                    
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                    
                        if pageAccessToken != nil && category != nil && name != nil && id != nil {
                            let newPage = Page(id: id!, name: name!, accessToken: pageAccessToken!, category: category!)
                            self.getPageBusinessAccountId(page: newPage) {
                                busAccountId in
                                if busAccountId != nil {
                                    newPage.businessAccountId = busAccountId!
                                    newPages.append(newPage)
                                    if pageIndex == pageCount {
                                        completion(newPages)
                                    }
                                }
                            }
                        }
                    }
                    
                    if pageCount == 0 {
                        completion([])
                    }
                    
                }
                else {
                    completion([])
                }
            }
        }
        else {
            print("Token was nil")
        }
    }
    
    func getPageBusinessAccountId(page: Page, completion: @escaping (String?) -> Void) {
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)?fields=instagram_business_account&access_token=\(page.accessToken)"
        getRequest(urlString: urlString) {
            jsonDataDict in
            let instaData = jsonDataDict["instagram_business_account"] as? [String: String]
            if instaData != nil {
                let id = instaData!["id"]
                if id != nil {
                    completion(id!)
                }
                else {
                    completion(nil)
                }
            }
            else {
                completion(nil)
            }
        }
    }
}


struct ConversationNavigationView: View {
    var conversation: Conversation
    let width: CGFloat
    let page: Page
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var correspondent: MetaUser
    
    init(conversation: Conversation, width: CGFloat, page: Page) {
        self.conversation = conversation
        self.width = width
        self.page = page
        self.correspondent = conversation.correspondent!
    }
    
    var body: some View {
        VStack {
            NavigationLink(destination: ConversationView(conversation: conversation, page: page).navigationTitle(conversation.correspondent!.username)) {
                HStack {
                    AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Color.gray } .frame(width: 55, height: 55) .clipShape(Circle()).offset(y: conversation.messages.last!.message == "" ? -6 : 0)
                    VStack {
                        Text(conversation.correspondent!.username).foregroundColor(self.colorScheme == .dark ? .white : .black).font(.system(size: 23)).frame(width: width * 0.85, alignment: .leading)
                        Text((conversation.messages.last!).message).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(.system(size: 23)).frame(width: width * 0.85, alignment: .leading)
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
    let page: Page
    @State var typingMessage: String = ""
    @State var placeholder: Bool = true
    @State var scrollDown: Bool = false
    @State var textEditorHeight : CGFloat = 100
    @FocusState var messageIsFocused: Bool
    var maxHeight : CGFloat = 250
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme

    init(conversation: Conversation, page: Page) {
        self.conversation = conversation
        self.page = page
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UINavigationBar.appearance().standardAppearance = appearance
    }

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
                    DynamicHeightTextBox(typingMessage: self.$typingMessage).frame(width: geometry.size.width * 0.9, alignment: .leading).padding(.trailing).offset(x: -5)
//                    ZStack(alignment: .leading) {
//                        Text(typingMessage)
//                            .font(.system(.body))
//                            .foregroundColor(.clear)
//                            .padding(15)
//                            .background(GeometryReader {
//                                Color.clear.preference(key: ViewHeightKey.self,
//                                                       value: $0.frame(in: .local).size.height)
//                            })
//
//                        TextEditor(text: $typingMessage)
//                            .font(.system(.body))
//                            .padding(7)
//                            .frame(height: min(textEditorHeight, maxHeight))
//                            .background(self.colorScheme == .dark ? Color.black : Color.white)
//                    }
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 5, style: .continuous)
//                            .strokeBorder(Color.gray, lineWidth: 1)
//                    )
//                    .focused($messageIsFocused)
                    
                    // Auto Generation buttons and send button
                    HStack {
                        AutoGenerateButton(buttonText: "Respond", width: geometry.size.width, height: geometry.size.height).padding(.leading)
                        AutoGenerateButton(buttonText: "Sell", width: geometry.size.width, height: geometry.size.height)
                        AutoGenerateButton(buttonText: "Yes", width: geometry.size.width, height: geometry.size.height)
                        AutoGenerateButton(buttonText: "No", width: geometry.size.width, height: geometry.size.height)
                        
                        // Send message button
                        Button(
                            action: {sendMessage(message: self.typingMessage, to: conversation.correspondent!)}
                        ) {
                           Image(systemName: "paperplane.circle.fill").font(.system(size: 35))
                       }.frame(width: geometry.size.width * 0.20, alignment: .leading)
                    }
                    
                    
                    
                }
//                .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
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
                print(sentMessageData)
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
    @FocusState var messageIsFocused: Bool
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
        .focused($messageIsFocused)
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
    }
    
}


struct MessageView : View {
    let width: CGFloat
    var currentMessage: Message
    var conversation: Conversation
    let page: Page
    @ObservedObject var correspondent: MetaUser
    
    init(width: CGFloat, currentMessage: Message, conversation: Conversation, page: Page) {
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
                AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Color.red } .frame(width: 45, height: 45) .clipShape(Circle())
                MessageBlurbView(contentMessage: currentMessage.message,
                                   isCurrentUser: isCurrentUser)
            }.frame(width: width * 0.875, alignment: .leading).padding(.leading).padding(.trailing)
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
    let page: Page
    var correspondent: MetaUser? = nil
    @Published var messages: [Message] = []
    
    init(id: String, updatedTime: String, page: Page) {
        self.id = id
        self.page = page
        self.updatedTime = Date().facebookStringToDate(fbString: updatedTime)
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
            }
        }
        return rList
    }
}

class Page: Hashable, Equatable {
    let id: String
    let name: String
    let accessToken: String
    let category: String
    var conversations: [Conversation] = []
    var businessAccountId: String? = nil
    var pageUser: MetaUser? = nil
    
    init(id: String, name: String, accessToken: String, category: String) {
        self.id = id
        self.name = name
        self.accessToken = accessToken
        self.category = category
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }

    static func ==(lhs: Page, rhs: Page) -> Bool {
        return lhs.id == rhs.id
    }
    
    func sortConversations() {
        self.conversations = self.conversations.sorted {$0.messages.last!.createdTime > $1.messages.last!.createdTime}
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
    
    func getProfilePicture(access_token: String) {
        let urlString = "https://graph.facebook.com/v16.0/\(self.id)?access_token=\(access_token)"
        getRequest(urlString: urlString) {
            profileData in
            let profilePicURL = profileData["profile_pic"] as? String
            if profilePicURL != nil {
                DispatchQueue.main.async {
                    self.profilePicURL = profilePicURL?.replacingOccurrences(of: "\\", with: "")
                }
            }
        }
    }
}


func getRequest(urlString: String, completion: @escaping ([String: AnyObject]) -> Void) {
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


//{"data":[{"access_token":"EAAPjZCIdKOzEBAKGE99Oci5Sz7h09X5a4SDrn3pZA8PV6ZCvlbmcpsiXwNMgCJ0oWkP75ouJBGvcmLyMKA1fv1Dur9F1ewUSDay9MtMkTyaPnOEQvzxDmQUQT6e5MWHr4e4ZCibJWyX6OlbvrncRpHxFCSSTwzZBksYakDIlpm2DkLkoN1jZBf","category":"Information Technology Company","category_list":[{"id":"1130035050388269","name":"Information Technology Company"}],"name":"MessageMate","id":"110824595249562","tasks":["ADVERTISE","ANALYZE","CREATE_CONTENT","MESSAGING","MODERATE","MANAGE"]},{"access_token":"EAAPjZCIdKOzEBAKMbZBTeEpVAfLfZBkqIkNpysACCqsEosMXjOajJ2CxfIVuBfTi2R2oxQCbnOtTjSZBsP6wJRR9Tylnj0Tnky1nk84eYv2wIs3oUpxpB4e2LuyQwHDc2WFlEcTBmCoR0C2Lp8ok7NBccKUZCgZCvROhHDtc8NF21FkrDp8iOP","category":"Software Company","category_list":[{"id":"1065597503495311","name":"Software Company"}],"name":"Axon","id":"102113192797755","tasks":["ADVERTISE","ANALYZE","CREATE_CONTENT","MESSAGING","MODERATE","MANAGE"]}],"paging":{"cursors":{"before":"QVFIUlh5Y1dnNk1vREFnOGN5ME9GLVlvMWROc0xJMS1vTWlYeEJGdFJySmdYblVESXI0OGhLcU9pSncxNkszek9qdlpYcHh6WWxEVnM3OXF1dm41SlcxX29B","after":"QVFIUkpqWndZAUEtzc0x2b3lwanlILXRPTWVDXzE5LUwxTVhSYWZA0dG56QlBLdDRqMlR3bkluYUxhZAUhkTTBpWlV3Y0FLX3N4czBqNjZASNFBpSnU3aUcyZA0Vn"}}
//
//
//    {"data":[{"id":"aWdfZAG06MTpJR01lc3NhZA2VUaHJlYWQ6MTc4NDE0NTQ2MDQxNDU4MTQ6MzQwMjgyMzY2ODQxNzEwMzAwOTQ5MTI4MTczMjI5OTEzOTU4NzQ3","updated_time":"2023-01-27T23:38:06+0000"},{"id":"aWdfZAG06MTpJR01lc3NhZA2VUaHJlYWQ6MTc4NDE0NTQ2MDQxNDU4MTQ6MzQwMjgyMzY2ODQxNzEwMzAwOTQ5MTI4MjEzMjYzMjMwNjY1MjI0","updated_time":"2023-01-27T23:29:47+0000"}]
//
//
//        {"messages":{"data":[{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTc2MzM0NTU3MzczNDg0MzY4ODM3NTc1NzU3MDA0OAZDZD","created_time":"2023-01-27T23:38:06+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTcxODAzNDc0OTE2MTA2NTQwMDY4NDg3NDAzOTI5NgZDZD","created_time":"2023-01-27T22:57:10+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTY5NzMzNjYyMzM3ODM0ODQwMzczMjcxNjE5MTc0NAZDZD","created_time":"2023-01-27T22:38:28+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTY5MjMxOTg0MTkzNDc4MTY4NjM5NDc3ODU1MDI3MgZDZD","created_time":"2023-01-27T22:33:56+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDgyOTIzMDY5NzMyMTA2MzY1ODA1MzU3MTUzOTEwNzg0MAZDZD","created_time":"2022-12-17T05:45:44+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDgyOTE3OTA2NTgzNTE2NDk4MTMyMTY2MjM1NDk0ODA5NgZDZD","created_time":"2022-12-17T04:59:05+0000"},{"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDgyOTE3Njg5Njc0ODE0NDQyMjQ4NTY3MjcwNDYwNjIwOAZDZD","created_time":"2022-12-17T04:57:08+0000"}]},"id":"aWdfZAG06MTpJR01lc3NhZA2VUaHJlYWQ6MTc4NDE0NTQ2MDQxNDU4MTQ6MzQwMjgyMzY2ODQxNzEwMzAwOTQ5MTI4MTczMjI5OTEzOTU4NzQ3"}
//
//
//        curl -i -X GET "https://graph.facebook.com/v9.0/aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTcxODAzNDc0OTE2MTA2NTQwMDY4NDg3NDAzOTI5NgZDZD?fields=id,created_time,from,to,message&access_token=EAAPjZCIdKOzEBAKMbZBTeEpVAfLfZBkqIkNpysACCqsEosMXjOajJ2CxfIVuBfTi2R2oxQCbnOtTjSZBsP6wJRR9Tylnj0Tnky1nk84eYv2wIs3oUpxpB4e2LuyQwHDc2WFlEcTBmCoR0C2Lp8ok7NBccKUZCgZCvROhHDtc8NF21FkrDp8iOP"
//
//
//        {"id":"aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDg5NTc2MzM0NTU3MzczNDg0MzY4ODM3NTc1NzU3MDA0OAZDZD","created_time":"2023-01-27T23:38:06+0000","from":{"username":"axon.messaging","id":"17841454604145814"},"to":{"data":[{"username":"evan.marrone","id":"6521113831237472"}]},"message":""}


//curl -i -X GET "https://graph.facebook.com/v9.0/aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDU0NjA0MTQ1ODE0OjM0MDI4MjM2Njg0MTcxMDMwMDk0OTEyODE3MzIyOTkxMzk1ODc0NzozMDgyOTE3OTA2NTgzNTE2NDk4MTMyMTY2MjM1NDk0ODA5NgZDZD?fields=id,created_time,from,to,message&access_token=EAAPjZCIdKOzEBAKMbZBTeEpVAfLfZBkqIkNpysACCqsEosMXjOajJ2CxfIVuBfTi2R2oxQCbnOtTjSZBsP6wJRR9Tylnj0Tnky1nk84eYv2wIs3oUpxpB4e2LuyQwHDc2WFlEcTBmCoR0C2Lp8ok7NBccKUZCgZCvROhHDtc8NF21FkrDp8iOP"
//
//
//curl -i -X GET \
// "https://graph.facebook.com/v16.0/6521113831237472/picture"


//"https://scontent-den4-1.cdninstagram.com/v/t51.2885-19/147454587_483650809463544_8013518899283133287_n.jpg?stp=dst-jpg_s200x200&_nc_cat=107&ccb=1-7&_nc_sid=8ae9d6&_nc_ohc=Q3zKGTK6HHQAX-C_mcR&_nc_ht=scontent-den4-1.cdninstagram.com&edm=ALmAK4EEAAAA&oh=00_AfDXOH3hYHcNc-d6fsE-_udK11cGdpZbGq-oOvLopJwh6Q&oe=640AA2EB"
