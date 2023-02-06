//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FBSDKLoginKit
import FirebaseFirestore

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
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Inbox").bold().font(.system(size: 30)).offset(x: 0).padding(.leading).padding(.bottom)

                    if self.loading {
                        Text("Loading").onAppear(perform: {
                            self.updatePages()
                        })
                    }
                    else {
                        ScrollView {
                            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                //self.loading = true
                                //self.getConversations()
                            }
                            if self.pages[1].conversations.count == 0 {
                                Text("No conversations. Pull down to refresh")
                            }
                            else {
                                ForEach(self.pages[1].conversations, id:\.self) { conversation in
                                    
                                    // TODO: Make sure ther is at least one message in the conversation
                                    if conversation.messages.count > 0 {
                                        ConversationNavigationView(conversation: conversation, width: geometry.size.width, page: self.pages[1])
                                    }
                                }
                            }
                        }.coordinateSpace(name: "pullToRefresh")
                    }
                }
            }
        }
    }
    
    
    func updatePages() {
        self.getPages() { pages in
            for page in pages {
                
                self.getPageBusinessAccountId(page: page) {
                    businessAccountId in
                    page.businessAccountId = businessAccountId
                    
                    self.getConversations(page: page) {
                        conversations in
                        page.conversations = conversations
                        for conversation in conversations {
                            self.getMessages(page: page, conversation: conversation) {
                                messages in
                                
                                print(page.name, conversation.id, messages)
                                conversation.messages = messages.sorted { $0.createdTime < $1.createdTime }
                                conversation.updateCorrespondent()
                                if page == pages.last && conversation == conversations.last {
                                    DispatchQueue.main.async {
                                        print("UPDATING")
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
    }
    
    func getRequest(urlString: String, completion: @escaping ([String: AnyObject]) -> Void) {
        let url = URL(string: urlString)!
        let request = URLRequest(url: url)
        
        let dataTask = URLSession.shared.dataTask(with: request) {(data, response, error) in
            print("starting data task")
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
    
    func getMessages(page: Page, conversation: Conversation, completion: @escaping ([Message]) -> Void) {
        // TODO: Only look for details on 20 most recent messages
        
        let urlString = "https://graph.facebook.com/v9.0/\(conversation.id)?fields=messages&access_token=\(page.accessToken)"
        self.getRequest(urlString: urlString) {
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
                            self.getRequest(urlString: messageDataURLString) {
                                messageDataDict in
                            
                                let fromDict = messageDataDict["from"] as? [String: AnyObject]
                                let toDictList = messageDataDict["to"] as? [String: AnyObject]
                                let message = messageDataDict["message"] as? String
                                
                                if toDictList != nil {
                                    let toDict = toDictList!["data"] as? [[String: AnyObject]]
                                
                                    // TODO: Support for group chats?
                                    if toDict!.count <= 1 {
                                        if fromDict != nil && toDict != nil && message != nil {
                                            let fromUsername = fromDict!["username"] as? String
                                            let fromId = fromDict!["id"] as? String
                                            let toUsername = toDict![0]["username"] as? String
                                            let toId = toDict![0]["id"] as? String
                                    
                                            if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil {
                                                let fromUser = MetaUser(id: fromId!, username: fromUsername!)
                                                let toUser = MetaUser(id: toId!, username: toUsername!)
                                                newMessages.append(Message(id: id!, message: message!, to: toUser, from: fromUser, createdTime: createdTime!))
                                            }
                                        }
                                    }
                                }
                            
                                indexCounter = indexCounter + 1
                                if indexCounter == messagePointerLen {
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
        let urlString = "https://graph.facebook.com/v9.0/\(page.id)/conversations?platform=instagram&access_token=\(page.accessToken)"
        self.getRequest(urlString: urlString) {
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
            let urlString = "https://graph.facebook.com/v9.0/me/accounts?access_token=\(self.session.facebookUserToken!)"
            self.getRequest(urlString: urlString) {
                jsonDataDict in
                NSLog("Received data:\n\(jsonDataDict))")
                let pages = jsonDataDict["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var newPages: [Page] = []
                    for page in pages! {
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if pageAccessToken != nil && category != nil && name != nil && id != nil {
                            newPages.append(Page(id: id!, name: name!, accessToken: pageAccessToken!, category: category!))
                        }
                    }
                    completion(newPages)
                }
            }
        }
        else {
            print("Token was nil")
        }
    }
    
    func getPageBusinessAccountId(page: Page, completion: @escaping (String) -> Void) {
        let urlString = "https://graph.facebook.com/v9.0/\(page.id)?fields=instagram_business_account&access_token=\(page.accessToken)"
        self.getRequest(urlString: urlString) {
            jsonDataDict in
            let instaData = jsonDataDict["instagram_business_account"] as? [String: String]
            if instaData != nil {
                let id = instaData!["id"]
                if id != nil {
                    completion(id!)
                }
            }
        }
    }
}


struct ConversationNavigationView: View {
    let conversation: Conversation
    let width: CGFloat
    let page: Page
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            NavigationLink(destination: ConversationView(conversation: conversation, page: page).navigationTitle(conversation.correspondent)) {
                HStack {
                    VStack {
                        Text(conversation.correspondent).foregroundColor(self.colorScheme == .dark ? .white : .black).font(.system(size: 23)).frame(width: width * 0.85, alignment: .leading)
                        Text((conversation.messages.last!).message).foregroundColor(.gray).font(.system(size: 23)).frame(width: width * 0.85, alignment: .leading)
                    }
                    Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
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

extension Date {
    func facebookStringToDate(fbString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.date(from: fbString) ?? Date()
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

class Conversation: Hashable, Equatable {
    let id: String
    let updatedTime: Date?
    let page: Page
    var correspondent: String = ""
    var messages: [Message] = []
    
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
    
    func updateCorrespondent() {
        for message in self.messages {
            if message.from.id != page.businessAccountId {
                self.correspondent = message.from.username
                return
            }
        }
    }
}

class Page: Hashable, Equatable {
    let id: String
    let name: String
    let accessToken: String
    let category: String
    var conversations: [Conversation] = []
    var businessAccountId: String? = nil
    
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
}


class MetaUser: Hashable, Equatable {
    let id: String
    let username: String
    
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
    
}


struct ConversationView: View {
    let conversation: Conversation
    let page: Page
    @State var typingMessage: String = ""
    @State var placeholder: Bool = true
    @State var scrollDown: Bool = false
    @State var textEditorHeight : CGFloat = 100
    @FocusState var messageIsFocused: Bool
    var maxHeight : CGFloat = 250
    @EnvironmentObject var session: SessionStore

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
                ScrollView {
                    ScrollViewReader {
                        value in
                        VStack {
                            ForEach(conversation.messages, id: \.self.id) { msg in
                                MessageView(width: geometry.size.width, currentMessage: msg, page: page).id(msg.id)
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

                HStack {
                    ZStack(alignment: .leading) {
                        Text(typingMessage)
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
                            .background(Color.black)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.gray, lineWidth: 1)
                    )
                    .focused($messageIsFocused)

                    Button(action: sendMessage) {
                       Image(systemName: "paperplane.circle.fill").font(.system(size: 35))
                   }.frame(width: geometry.size.width * 0.20, alignment: .center)
                }.onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
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

    func sendMessage() {

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

struct MessageView : View {
    let width: CGFloat
    var currentMessage: Message
    let page: Page
        
    var body: some View {
        let isCurrentUser = page.businessAccountId == currentMessage.from.id
        if !isCurrentUser {
            HStack {
                Image(systemName: "person.circle")
                .resizable()
                .frame(width: 40, height: 40)
                .cornerRadius(20)

                MessageBlurbView(contentMessage: currentMessage.message,
                                   isCurrentUser: isCurrentUser)
            }.frame(width: width, alignment: .leading).padding(.leading)
        }
        else {
            MessageBlurbView(contentMessage: currentMessage.message,
                             isCurrentUser: isCurrentUser).frame(width: width * 0.90, alignment: .trailing).padding(.trailing)
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

extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
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

