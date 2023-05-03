//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import UIKit
import SwiftUI
import AVKit
import FBSDKLoginKit

import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import CoreData


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


let messagingPlatforms: [String] = ["instagram", "facebook"]


// TODO: Add full screen for story mentions and replies
// TODO: Check on local notifcations waking app up from termination
// TODO: Better multi page management
// TODO: Delete account workflow
// TODO: Sending old messages not showing up
// TODO: Fix account image
// TODO: Add indication of no business account if there is none in place of account image

// TODO: Put human tag in POST request after 24 hours
// TODO: Fix width of message box
// TODO: Cache messages in phone storage
// TODO: Analytics class for button presses etc.
// TODO: Configure firebase analytics
// TODO: Send multilinks as comma separated
// TODO: Send last 7 messages with generate response request
// TODO: Fix Facebook profile pics not loading
// TODO: Test Facebook and Instagram snapshot listeners
// TODO: Auto reply toggle in conversation
// TODO: Make a cancel button when generating response
// TODO: Prompt to reply / voice to text
// TODO: Bug where unread counter is incrementing when in conversation view and receive a message
// TODO: Enforce unique IDs on Core Data Entities and make sure they aren't throwing errors in code
// TODO: Make sure loading is stopped / counter is decremented at appopriate times
// TODO: Get onAppear to stop triggering twice
// TODO: Image attachments unread message counters aren't decrementing. Probably because of no message id...
// TODO: Business info Done button misplaced

// TODO: Calendar


struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        GeometryReader {
            geometry in
            if !self.session.loadingFacebookUserToken && self.session.facebookUserToken == nil {
                FacebookAuthenticateView(width: geometry.size.width, height: geometry.size.height).environmentObject(self.session)
            }
            else {
                VStack {
                    ConversationsView(width: geometry.size.width, height: geometry.size.height, geometryReader: geometry)
                        .environmentObject(self.session)
                        .environment(\.managedObjectContext, self.moc)
                    
//                    Text("Save database").onTapGesture {
//                        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
//                        let appSupportURL = urls[urls.count - 1]
//                        let sqliteURL = appSupportURL.appendingPathComponent("Messaging.sqlite")
//                        let sqliteURL1 = appSupportURL.appendingPathComponent("Messaging.sqlite-wal")
//                        let sqliteURL2 = appSupportURL.appendingPathComponent("Messaging.sqlite-shm")
//                        print("sqlite \(sqliteURL)")
//
//                        do {
//                            try FileManager.default.copyItem(at: sqliteURL, to: URL(fileURLWithPath: "/Users/erickverleye/Desktop/Projects/MessageMate/sqlite/Messaging.sqlite"))
//                            try FileManager.default.copyItem(at: sqliteURL1, to: URL(fileURLWithPath: "/Users/erickverleye/Desktop/Projects/MessageMate/sqlite/Messaging.sqlite-wal"))
//                            try FileManager.default.copyItem(at: sqliteURL2, to: URL(fileURLWithPath: "/Users/erickverleye/Desktop/Projects/MessageMate/sqlite/Messaging.sqlite-shm"))
//
//                        }
//                        catch {
//
//                        }
//                    }
                }
            }
        }
    }
}


struct ConversationsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State var firstAppear: Bool = true
    @State var missingFields: [String] = []
    @State var searchText: String = ""
    @State var sortedConversations: [Conversation] = []
    @State var corresponsdentsSearch: [Conversation] = []
    @State var messagesSearch: [Conversation] = []
    @State var showingSearch: Bool = false
    @State var waitingForReset: Bool = false
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(sortDescriptors: []) var conversationsHook: FetchedResults<Conversation>
    @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
    @FetchRequest(sortDescriptors: []) var existingUsers: FetchedResults<MetaUser>
    
    @State var pagesToUpdate: [MetaPageModel]? { didSet { self.writeNewPages() } }
    @State var conversationsToUpdate: [ConversationModel]? { didSet { self.writeNewConversations() } }
    @State var messagesToUpdate: [MessageModel]? { didSet { self.writeNewMessages() } }
    
    let db = Firestore.firestore()
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    
    var body: some View {
        NavigationView {
        
            VStack(alignment: .leading) {
                if self.session.loadingPageInformation {
                    LottieView(name: "Paperplane")
                        .onTapGesture(perform: {
                            self.initializePageInfo()
                        }
                    )
                }
                
                else {
                    if self.session.selectedPage != nil {
                        
                        ScrollView {
                            
                            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                self.initializePageInfo()
                            }
                            
                            if self.missingFields.count > 0 {
                                MissingFieldsView(missingFields: self.$missingFields, width: self.width, height: self.height)
                            }
                            
                            else {
                                if self.sortedConversations.count == 0 {
                                    Text("No conversations. Pull down to refresh.").font(Font.custom(REGULAR_FONT, size: 30))
                                }
                                
                                else {
                                        
                                    if self.showingSearch {
                                        InboxSearchView(correspondents: self.$corresponsdentsSearch, messages: self.$messagesSearch, searchText: self.$searchText, showingSearch: self.$showingSearch, width: width, height: height, geometryReader: self.geometryReader)
                                            .animation(Animation.easeInOut(duration: 0.2), value: self.showingSearch)
                                            .transition(.move(edge: .bottom))
                                    }
                                    
                                    else {
                                        if self.waitingForReset {
                                            LottieView(name: "Loading-2").frame(width: 100, height: 100)
                                        }
                                        else {
                                            DefaultInboxView(searchText: self.$searchText, showingSearch: self.$showingSearch, sortedConversations: self.$sortedConversations, width: width, height: height, geometryReader: self.geometryReader)
                                                .animation(Animation.easeInOut(duration: 0.2), value: self.showingSearch)
                                                .transition(.move(edge: .bottom))
                                        }
                                    }
                                }
                            }
                        }
                        .coordinateSpace(name: "pullToRefresh")
                        .onAppear(perform: {
                            if self.session.selectedPage != nil {
                                self.session.getMissingRequiredFields(page: self.session.selectedPage!) {
                                    missingFields in
                                    self.missingFields = missingFields
                                }
                            }
                        })
                        // Initialize things
                        .onAppear(perform: {
                            print("On Appear A")
                            self.setSortedConversations()
                            self.refreshUserProfilePictures()
                            self.addActivePageListeners()
                        })
                        .onReceive(self.conversationsHook.publisher.count(), perform: {
                            _ in
                            if !self.session.loadingPageInformation {
                                self.setSortedConversations()
                            }
                        })
                    }
                    
                    else {
                        NoBusinessAccountsLinkedView(width: width, height: height).environmentObject(self.session)
                            .onChange(of: self.session.facebookUserToken, perform: { newToken in
                                self.initializePageInfo()
                        })
                    }
                }
            }
        }
        .accentColor(Color("Purple"))
        .onChange(of: searchText, perform: {
            searchText in
            self.writeSearchResults(searchText: searchText)
        })
        .onChange(of: self.showingSearch, perform: {
            showing in
            if !showing {
                self.waitingForReset = true
                self.resetSearch()
            }
        })
        // TODO: Add / remove listeners when page changes
    }
    
    func sortConversations(conversations: [Conversation]) -> [Conversation] {
        var sortTuples: [(date: Date, conversation: Conversation)] = []
        for conversation in conversations {
            if let messageSet = conversation.messages as? Set<Message> {
                let lastMessage = sortMessages(messages: Array(messageSet)).last
                if lastMessage == nil {
                    continue
                }
                sortTuples.append((date: lastMessage!.createdTime!, conversation: conversation))
            }
        }
        
        sortTuples.sort(by: {$0.date > $1.date })
        
        var sortedConversations: [Conversation] = []
        for tuple in sortTuples {
            sortedConversations.append(tuple.conversation)
        }
        return sortedConversations
    }
}


struct DefaultInboxView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var searchText: String
    @Binding var showingSearch: Bool
    @Binding var sortedConversations: [Conversation]
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    
    var body: some View {
        VStack {
            InboxNavBar(width: self.width, height: self.height).environmentObject(self.session)
            
            SearchBar(text: $searchText)
                .frame(width: width * 0.925)
                .padding(.top)
                .padding(.bottom)
                .onTapGesture {
                    self.showingSearch = true
                }
            
            ConversationNavigationViewList(sortedConversations: self.$sortedConversations, width: width, height: height, geometryReader: self.geometryReader).environmentObject(self.session)
        }
    }
}


struct InboxSearchView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var correspondents: [Conversation]
    @Binding var messages: [Conversation]
    @Binding var searchText: String
    @Binding var showingSearch: Bool
    @FocusState var isSearchFocused: Bool

    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy

    var body: some View {
        VStack {
            HStack {
                SearchBar(text: $searchText).frame(width: width * 0.75)
                    .padding(.top)
                    .padding(.bottom)
                    .focused(self.$isSearchFocused)
                Button(action: {
                    self.searchText = ""
                    self.showingSearch = false
                }) {
                    Text("Cancel")
                }
            }

            HStack(spacing: 1) {
                ForEach(correspondents.prefix(4), id:\.self) {
                    conversation in
                    if conversation.metaPage != nil {
                        CorrespondentSearchNavigationView(conversation: conversation, page: conversation.metaPage!, width: width, height: height, geometryReader: geometryReader).environmentObject(self.session).padding().frame(height: height * 0.10)
                    }
                }
                Spacer()
            }.frame(width: width * 0.95)

            Text("Conversations").font(Font.custom(BOLD_FONT, size: 25)).frame(width: width * 0.90, alignment: .leading).padding(.top)

            ConversationNavigationViewList(sortedConversations: self.$messages, width: width, height: height, geometryReader: self.geometryReader)

        }.onAppear(perform: {
            self.isSearchFocused = true
        })
    }
}


struct ConversationNavigationViewList: View {
    @EnvironmentObject var session: SessionStore
    @Binding var sortedConversations: [Conversation]
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    let navigationViewPreview: String? = nil
    
    var body: some View {
        ForEach(self.sortedConversations, id:\.self.uid!) {
            conversation in
            if let messageSet = conversation.messages as? Set<Message> {
                if messageSet.count > 0 && conversation.correspondent != nil {
                    ConversationNavigationView(conversation: conversation, width: width, height: height, geometryReader: self.geometryReader, page: self.session.selectedPage!, messageToScrollTo: conversation.messageToScrollTo)
                        .environmentObject(self.session)
                }
            }
        }
    }
}


struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $text)
                .disableAutocorrection(true)
            if !self.text.isEmpty {
                Image(systemName: "x.circle.fill").onTapGesture {
                    self.text = ""
                }
                .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}


struct MissingFieldsView: View {
    @Binding var missingFields: [String]
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .center) {
            Image("undraw_add_information_j2wg").resizable().frame(width: width * 0.75, height: height * 0.35).offset(y: 0).padding()
    
            Text("Please go to the business information tab and add information for the following fields before replying to messages :").frame(width: width * 0.75, height: height * 0.25).lineSpacing(7).font(Font.custom(REGULAR_FONT, size: 20)).multilineTextAlignment(.center)
            ForEach(self.missingFields, id: \.self) {
                field in
                Text(field.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }
    }
    
}


struct InboxNavBar: View {
    @EnvironmentObject var session: SessionStore
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Text("Messages")
                .bold()
                .font(Font.custom("Monsterrat-ExtraBold", size: 30))
                .frame(width: width * 0.9, alignment: .leading)
    
            Text("You have \(self.session.unreadMessages == 0 ? "no" : String(self.session.unreadMessages)) new \(self.session.unreadMessages != 1 ? "messages" : "message")")
                .frame(width: width * 0.9, alignment: .leading)
                .foregroundColor(.gray)
                .font(Font.custom(REGULAR_FONT, size: 15))
        }
    }
}


struct NoBusinessAccountsLinkedView: View {
    @EnvironmentObject var session: SessionStore
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack {
            Image("undraw_access_account_re_8spm").resizable().frame(width: width * 0.75, height: height * 0.35).offset(y: 0).padding()
            Text("There are no business accounts linked to you. Please add a business account to your Facebook account and reauthenticate.").font(Font.custom(REGULAR_FONT, size: 30)).padding()
            Button(action: {self.session.facebookLogin(authWorkflow: false)}) {
                Image("facebook_login").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit)
                    .frame(width: width * 0.80, height: height * 0.15, alignment: .top)
            }
        }
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

struct CorrespondentSearchNavigationView: View {
    @EnvironmentObject var session: SessionStore
    @State var navigate: Bool = false
    let conversation: Conversation
    let page: MetaPage
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy

    var body: some View {
        let navTitle = conversation.correspondent?.name ?? conversation.correspondent?.username ?? conversation.correspondent?.email ?? ""

        NavigationLink(destination: ConversationView(conversation: conversation, page: page, navigate: self.$navigate, width: width, height: height, geometryReader: self.geometryReader, fromCorrespondentSearch: true).environmentObject(self.session)
            .navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem {
                    HStack {
                        HStack {
                            AsyncImage(url: conversation.correspondent?.profilePictureURL ?? URL(string: "")) { image in image.resizable() } placeholder: { EmptyView() } .frame(width: 37.5, height: 37.5) .overlay(
                                Circle()
                                    .stroke(Color("Purple"), lineWidth: 3)
                            ).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 0.5) {
                                Text(navTitle).font(Font.custom(BOLD_FONT, size: 18))
                                switch conversation.correspondent?.platform {
                                case "instagram":
                                    Image("instagram_logo").resizable().frame(width: 20.5, height: 20.5)
                                case "facebook":
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
            VStack {
                let displayName = conversation.correspondent?.displayName()
                AsyncImage(url: conversation.correspondent?.profilePictureURL ?? URL(string:  "")) { image in image.resizable() } placeholder: { InitialsView(name: displayName ?? "").font(.system(size: 60)) } .frame(width: 65, height: 65) .overlay(
                    Circle()
                        .stroke(Color("Purple"), lineWidth: 3)
                ).clipShape(Circle())
                
                Text(displayName ?? "").font(Font.custom(REGULAR_FONT, size: 12.5)).lineLimit(1)
                
//                let nameSplit = conversation.correspondent?.displayName().split(separator: " ")
//                VStack {
//                    ForEach((nameSplit ?? []).prefix(2), id:\.self) { name in
//                        Text(name).font(Font.custom(REGULAR_FONT, size: 12.5)).lineLimit(1)
//                    }
//                }
            }
        }
    }
}


struct ConversationNavigationView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var conversation: Conversation
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    let page: MetaPage
    let messageToScrollTo: Message?
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var correspondent: MetaUser
    @ObservedObject var pushNotificationState = PushNotificationState.shared
    @State var navigate: Bool = false
    @State var messages: [Message] = []
    @FetchRequest var messagesRequest: FetchedResults<Message>

    init(conversation: Conversation, width: CGFloat, height: CGFloat, geometryReader: GeometryProxy, page: MetaPage, messageToScrollTo: Message? = nil) {
        self.conversation = conversation
        self.width = width
        self.height = height
        self.geometryReader = geometryReader
        self.page = page
        self.correspondent = conversation.correspondent!
        self.messageToScrollTo = messageToScrollTo
        let predicate = NSPredicate(format: "conversation.id == %@", conversation.id!)
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.createdTime, ascending: true)]
        request.predicate = predicate
        _messagesRequest = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        VStack {
            let displayName = self.correspondent.displayName() ?? ""
            
            NavigationLink(destination: ConversationView(conversation: conversation, page: page, navigate: self.$navigate, width: width, height: height, geometryReader: self.geometryReader, messageToScrollTo: self.messageToScrollTo, fromCorrespondentSearch: false).environmentObject(self.session)
                .navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem {
                        HStack {
                            HStack {
                                AsyncImage(url: self.correspondent.profilePictureURL ?? URL(string: "")) { image in image.resizable() } placeholder: { EmptyView() } .frame(width: 37.5, height: 37.5) .overlay(
                                    Circle()
                                        .stroke(Color("Purple"), lineWidth: 3)
                                ).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 0.5) {
                                    Text(displayName).font(Font.custom(BOLD_FONT, size: 18))
                                    switch self.correspondent.platform {
                                    case "instagram":
                                        Image("instagram_logo").resizable().frame(width: 20.5, height: 20.5)
                                    case "facebook":
                                        Image("facebook_logo").resizable().frame(width: 20.5, height: 20.5)
                                    default:
                                        EmptyView()
                                    }
                                }.offset(y: -2)
                            }.frame(width: width * 0.60, alignment: .leading).padding().onTapGesture {
                                openProfile(correspondent: self.correspondent)
                            }
                            Spacer()
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }, isActive: $navigate
            ) {
                if self.messages.last != nil {
                    ZStack {
                        HStack {
                            AsyncImage(url: self.correspondent.profilePictureURL ?? URL(string: "")) { image in image.resizable() } placeholder: { InitialsView(name: displayName).font(.system(size: 50)) } .frame(width: 55, height: 55).overlay(
                                Circle()
                                    .stroke(Color("Purple"), lineWidth: 3)
                            ).clipShape(Circle()).offset(y: self.messages.last?.message ?? "" == "" ? -6 : 0)
                            
                            VStack(spacing: 0.5) {
                                HStack {
                                    Text(displayName).foregroundColor(self.colorScheme == .dark ? .white : .black).font(Font.custom(REGULAR_FONT, size: 22)).lineLimit(1)
                                    Image(self.correspondent.platform == "instagram" ? "instagram_logo" : "facebook_logo").resizable().frame(width: 15.5, height: 15.5)
                                }.frame(width: width * 0.55, alignment: .leading)
                            
                                HStack {
                                    if self.messageToScrollTo != nil {
                                        Text(self.messageToScrollTo!.message!).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                    }
                                    else {
                                        
                                        if self.messages.last!.instagramStoryMention != nil {
                                            Text("\(self.correspondent.name ?? "") mentioned you in their story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                        }
                                        else {
                                            
                                            if self.messages.last!.imageAttachment != nil {
                                                Text("\(self.correspondent.name ?? "") sent you an image").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                            }
                                            
                                            else {
                                                
                                                if self.messages.last!.instagramStoryReply != nil {
                                                    Text("\(self.correspondent.name ?? "") replied to your story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                                }
                                                
                                                else {
                                                    
                                                    if self.messages.last!.videoAttachment != nil {
                                                        Text("\(self.correspondent.name ?? "") sent you a video").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                                    }
                                                    
                                                    else {
                                                        
                                                        Text((self.messages.last!).message ?? "").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            let timeInterval = self.messageToScrollTo == nil ? self.messages.last!.createdTime!.timeIntervalSinceNow : self.messageToScrollTo!.createdTime!.timeIntervalSinceNow
                            let lastMessageIntervalString = self.makeTimeElapsedString(elapsedTime: timeInterval)
                            Text(lastMessageIntervalString).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 10)).frame(width: width * 0.20)

                        }
                        
                        if !self.messages.last!.opened {
                            HStack(spacing: 0) {
                                Color("Purple").frame(width: width * 0.01, height: 75)
                                Color.offWhite.frame(width: width * 0.99, height: 75).opacity(0.10)
                            }
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
        .onAppear(perform: {
            var newMessages: [Message] = []
            for message in self.messagesRequest {
                newMessages.append(message)
            }
            self.messages = newMessages
        })
        .onReceive(self.messagesRequest.publisher.count(), perform: {
            _ in
            var newMessages: [Message] = []
            for message in self.messagesRequest {
                newMessages.append(message)
            }
            self.messages = newMessages
        })
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
    
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack {
            Image("undraw_access_account_re_8spm").resizable().frame(width: width * 0.75, height: height * 0.35).offset(y: 0).padding()
            Text("Please log in with Facebook to link your Messenger conversations").font(Font.custom(REGULAR_FONT, size: 25)).frame(height: height * 0.25, alignment: .center).padding()
            Button(action: {self.session.facebookLogin(authWorkflow: false)}) {
                Image("facebook_login").resizable().cornerRadius(3.0).aspectRatio(contentMode: .fit)
                    .frame(width: width * 0.80, height: height * 0.15, alignment: .top)
            }
        }
        
    }
}


struct TextControlView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var showCouldNotGenerateResponse: Bool
    @Binding var messageSendError: String
    @Binding var typingMessage: String
    var conversation: Conversation
    
    let height: CGFloat
    let width: CGFloat
    let page: MetaPage
    let messageToScrollTo: Message?
    let fromCorrespondentSearch: Bool
    let geometryReader: GeometryProxy
        
    var body: some View {
            VStack {
                
                DynamicHeightTextBox(typingMessage: self.$typingMessage, messageSendError: self.$messageSendError, width: width, height: height, conversation: conversation, page: page, geometryReader: geometryReader, messageToScrollTo: self.messageToScrollTo, fromCorrespondentSearch: self.fromCorrespondentSearch).frame(width: width * 0.925).environmentObject(self.session)
                
                Spacer()
                HStack(spacing: 2) {
                    
                    DeleteTypingTextButton(width: self.width, height: self.height, typingText: self.$typingMessage)
                            
                    AutoGenerateButton(buttonText: "Respond", width: width, height: height, conversationId: self.conversation.id!, pageAccessToken: self.page.accessToken!, pageName: self.page.name!, accountId: self.page.id!, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
            
                    AutoGenerateButton(buttonText: "Sell", width: width, height: height, conversationId: self.conversation.id!, pageAccessToken: self.page.accessToken!, pageName: self.page.name!, accountId: self.page.id!, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
          
                    AutoGenerateButton(buttonText: "Yes", width: width, height: height, conversationId: self.conversation.id!, pageAccessToken: self.page.accessToken!, pageName: self.page.name!, accountId: self.page.id!, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
                                
                    AutoGenerateButton(buttonText: "No", width: width, height: height, conversationId: self.conversation.id!, pageAccessToken: self.page.accessToken!, pageName: self.page.name!, accountId: self.page.id!, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
                    
                }.padding(.top).padding(.bottom)
            }
            .padding(.bottom)
            .padding(.top)
    }
}


struct MessageDateHeaderView: View {
    
    let msg: Message
    let width: CGFloat
    let dateString: String
    
    init (msg: Message, width: CGFloat) {
        self.msg = msg
        self.width = width
                
        let dates = Calendar.current.dateComponents([.hour, .minute, .month, .day], from: msg.createdTime!)
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
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    
   // @Binding var openMessages: Bool
    
    var maxHeight : CGFloat = 250
    
    let page: MetaPage
    let messageToScrollTo: Message?
    let fromCorrespondentSearch: Bool

    init(conversation: Conversation, page: MetaPage, navigate: Binding<Bool>, width: CGFloat, height: CGFloat, geometryReader: GeometryProxy, messageToScrollTo: Message? = nil, fromCorrespondentSearch: Bool) {
        self.conversation = conversation
        self.page = page
        self.width = width
        self.height = height
        self.geometryReader = geometryReader
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UINavigationBar.appearance().standardAppearance = appearance
        _navigate = navigate
        self.messageToScrollTo = messageToScrollTo
        self.fromCorrespondentSearch = fromCorrespondentSearch
    }
    
    var body: some View {
            
            ZStack {
                VStack {
                    
                    TextControlView(showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse, messageSendError: self.$messageSendError, typingMessage: self.$typingMessage, conversation: self.conversation, height: height, width: width, page: page, messageToScrollTo: self.messageToScrollTo, fromCorrespondentSearch: self.fromCorrespondentSearch, geometryReader: geometryReader).focused($messageIsFocused)
                        .environmentObject(self.session)
                    
                }
                .opacity(self.session.videoPlayerUrl != nil || self.session.fullScreenImageUrlString != nil ? 0.10 : 1)
                .transition(AnyTransition.scale.animation(.easeInOut(duration: 0.50)))
                
                if self.session.videoPlayerUrl != nil {
                    let player = AVPlayer(url: self.session.videoPlayerUrl!)
                    VStack {
                        Image(systemName: "xmark").font(.system(size: 30)).frame(width: width, alignment: .leading).onTapGesture {
                            self.session.videoPlayerUrl = nil
                            player.pause()
                        }.padding(.bottom).padding(.leading)

                        VideoPlayer(player: player)
                            .frame(height: 1000).frame(width: width * 0.85, height: height * 0.90, alignment: .leading)
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
                        Image(systemName: "xmark").font(.system(size: 30)).frame(width: width, alignment: .leading).onTapGesture {
                            self.session.fullScreenImageUrlString = nil
                        }.padding(.bottom).padding(.leading)

                        AsyncImage(url: URL(string: self.session.fullScreenImageUrlString!)) {
                            image in
                            image.resizable()
                        } placeholder: {
                            LottieView(name: "Loading-2").frame(width: 50, height: 50, alignment: .leading)
                        }
                            .frame(height: 1000).frame(width: width * 0.85, height: height * 0.90, alignment: .leading)
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
                        .frame(width: width * 0.85, height: 150, alignment: .center).padding()
                        .overlay(
                            VStack {
                                Text("Could not generate a response").frame(width: width * 0.85, height: 150, alignment: .center)
                            }
                        )
                }

                if self.messageSendError != "" {
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundColor(Color.blue)
                        .frame(width: width * 0.85, height: 150, alignment: .center)
                        .overlay(
                            Text(self.messageSendError).frame(width: width * 0.85, height: 150, alignment: .center)
                        ).padding(.leading)
                }
            }
        .onDisappear(perform: {
            self.navigate = false
        })
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
    @Binding var typingText: String
    @Binding var showCouldNotGenerateResponse: Bool
    @FocusState var textBoxIsFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        Button(action: {
            DispatchQueue.main.async {
                self.session.autoGeneratingMessage = true
            }
            generateResponse(responseType: self.buttonText.lowercased(), conversationId: conversationId, pageAccessToken: pageAccessToken, pageName: pageName, accountId: accountId) {
                message in
                
                if message != "" {
                    self.textBoxIsFocused = false
                    self.typingText = message
                    DispatchQueue.main.async {
                        self.session.autoGeneratingMessage = false
                    }
                }
                else {
                    DispatchQueue.main.async {
                        self.session.autoGeneratingMessage = false
                    }
                    self.showCouldNotGenerateResponse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.showCouldNotGenerateResponse = false
                    }
                }
            }
        }) {
            Text(self.buttonText).foregroundColor(.white).font(.system(size: 13)).bold()
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
                                .fill(Color("Purple"))
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
                                .fill(Color("Purple"))
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 10, y: 10)
                                .shadow(color: Color.white.opacity(0.7), radius: 10, x: -5, y: -5)
                                .frame(width: width * 0.165, height: width * 0.165)
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
                    .fill(Color("Purple"))
                    .shadow(color: Color.darkStart, radius: 5, x: 1.5, y: 1.5)
                    .shadow(color: Color.darkEnd, radius: 5, x: -1.5, y: -1.5)
                    .frame(width: width * 0.165, height: width * 0.165)

            } else {
                shape
                    .fill(Color("Purple"))
                    .shadow(color: Color.darkStart, radius: 5, x: -1.5, y: -1.5)
                    .shadow(color: Color.darkEnd, radius: 5, x: 1.5, y: 1.5)
                    .frame(width: width * 0.165, height: width * 0.165)
            }
        }
    }
}


struct DeleteTypingTextButton: View {
    let width: CGFloat
    let height: CGFloat
    @Binding var typingText: String
    
    var body: some View {
        Button(action: {
            self.typingText = ""
        }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
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


struct GeometryGetter: View {
    @Binding var rect: CGRect

    var body: some View {
        GeometryReader { (g) -> Path in
            print("width: \(g.size.width), height: \(g.size.height)")
            DispatchQueue.main.async { // avoids warning: 'Modifying state during view update.' Doesn't look very reliable, but works.
                self.rect = g.frame(in: .global)
            }
            return Path() // could be some other dummy view
        }
    }
}


struct DynamicHeightTextBox: View {
    @EnvironmentObject var session: SessionStore
    @Binding var typingMessage: String
    @Binding var messageSendError: String
    @State var textEditorHeight : CGFloat = 65
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var moc
    @FocusState var textEditorIsFocused: Bool
    @State var messages: [Message] = []

    let height: CGFloat
    let width: CGFloat
    let conversation: Conversation
    let page: MetaPage
    let geometryReader: GeometryProxy
    let messageToScrollTo: Message?
    let fromCorrespondentSearch: Bool
    
    @FetchRequest var messagesRequest: FetchedResults<Message>

    init(typingMessage: Binding<String>, messageSendError: Binding<String>, width: CGFloat, height: CGFloat, conversation: Conversation, page: MetaPage,         geometryReader: GeometryProxy, messageToScrollTo: Message?, fromCorrespondentSearch: Bool) {
        _typingMessage = typingMessage
        _messageSendError = messageSendError
        self.width = width
        self.height = height
        self.conversation = conversation
        self.page = page
        self.geometryReader = geometryReader
        self.messageToScrollTo = messageToScrollTo
        self.fromCorrespondentSearch = fromCorrespondentSearch
        
        let predicate = NSPredicate(format: "conversation.id == %@", conversation.id!)
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.createdTime, ascending: true)]
        request.predicate = predicate
        _messagesRequest = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    ScrollViewReader {
                        value in
                        VStack {
                            ForEach(self.messages, id: \.self.uid!) { msg in
                                if msg.dayStarter {
                                    MessageDateHeaderView(msg: msg, width: width)
                                }
                                MessageView(width: width, currentMessage: msg, conversation: conversation, page: page, messageToScrollTo: self.messageToScrollTo, fromCorrespondentSearch: self.fromCorrespondentSearch).id(msg.uid!)
                                    .onAppear(perform: {
                                        print(msg.message, msg.uid)
                                        if !msg.opened {
                                            msg.opened = true
                                            try? self.moc.save()
                                            if self.session.unreadMessages > 0 {
                                                self.session.unreadMessages = self.session.unreadMessages - 1
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .onChange(of: typingMessage) { _ in
                            value.scrollTo(self.messages.last?.uid!)
                        }
                        .onChange(of: self.messages) { _ in
                            if self.messageToScrollTo != nil && !self.fromCorrespondentSearch {
                                print("SCROLLING")
                                value.scrollTo(self.messageToScrollTo!.uid!)
                            }
                            else {
                                value.scrollTo(self.messages.last?.uid!)
                            }
                        }
                        .onChange(of: textEditorIsFocused) {
                            _ in
                            value.scrollTo(self.messages.last?.uid!)
                        }
                    }
                }
                .frame(height: max(50, self.geometryReader.size.height - self.textEditorHeight - 200))
                .onTapGesture {
                    self.textEditorIsFocused = false
                }
                Spacer()
            }
            .onAppear(perform: {
                var newMessages: [Message] = []
                for message in self.messagesRequest {
                    newMessages.append(message)
                }
                self.messages = newMessages
            })
            .onReceive(self.messagesRequest.publisher.count(), perform: {
                _ in
                print("On receive messages request")
                var newMessages: [Message] = []
                for message in self.messagesRequest {
                    newMessages.append(message)
                }
                self.messages = newMessages
            })
            
            VStack {
                Spacer()

                if self.session.autoGeneratingMessage {
                    LottieView(name: "Loading-2").frame(width: self.width, height: self.height * 0.10, alignment: .leading)
                }

                else {
                    HStack {

                        ZStack(alignment: .bottomLeading) {
                            Text(self.typingMessage)
                                .font(.system(.body))
                                .foregroundColor(.clear)
                                .padding(14)
                                .background(GeometryReader {
                                    Color.clear.preference(key: ViewHeightKey.self,
                                                           value: $0.frame(in: .local).size.height)
                                })

                            TextEditor(text: $typingMessage)
                                .font(.system(.body))
                                .padding(7)
                                .frame(height: self.textEditorHeight)
                                .background(self.colorScheme == .dark ? Color.black : Color.white)
                                .focused(self.$textEditorIsFocused)
                        }.frame(width: self.width * 0.85)

                        VStack {
                            Spacer()

                            // Send message button
                            Button(
                                action: {
                                    self.sendMessage(message: self.typingMessage, to: conversation.correspondent!, conversation: self.conversation) {
                                        response in
                                        self.typingMessage = ""
                                        self.messageSendError = (response["error"] as? [String: Any])?["message"] as? String ?? ""
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                            self.messageSendError = ""
                                        }
                                    }
                                }
                            ) {
                                Image(systemName: "paperplane.circle")
                                    .offset(x: -5, y: self.typingMessage != "" ? -3 : -1)
                                    .font(.system(size: 35))
                                    .frame(height: 18, alignment: .bottom).foregroundColor(Color("Purple"))
                            }
                        }.frame(height: textEditorHeight)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color("Purple"), lineWidth: 2)
                    )
                    .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
                }

            }
            
        }
    }
    
    func sendMessage(message: String, to: MetaUser, conversation: Conversation, completion: @escaping ([String: Any]) -> Void) {
        /// API Reference: https://developers.facebook.com/docs/messenger-platform/reference/send-api/
        let urlString = "https://graph.facebook.com/v16.0/\(page.id!)/messages?access_token=\(page.accessToken!)"
        let data: [String: Any] = ["recipient": ["id": to.id], "message": ["text": message]]
        let jsonData = try? JSONSerialization.data(withJSONObject: data)
        
        if jsonData != nil {
            print("Message Data not Nil")
            postRequestJSON(urlString: urlString, data: jsonData!) {
                sentMessageData in
                if sentMessageData != nil {
                    print("SA")
                    let messageId = sentMessageData!["message_id"] as? String
                
                    if messageId != nil {
                        print("SB")
                       
                        let createdDate = Date(timeIntervalSince1970: NSDate().timeIntervalSince1970)
                        let lastDate = Calendar.current.dateComponents([.month, .day], from: self.messages.last!.createdTime!)
                        let messageDate = Calendar.current.dateComponents([.month, .day], from: createdDate)
                        
                        let dayStarter = lastDate.month! != messageDate.month! || lastDate.day! != messageDate.day!
                        
                        let newMessage = Message(context: self.moc)
                        newMessage.uid = UUID()
                        newMessage.id = messageId
                        newMessage.message = message
                        newMessage.to = conversation.correspondent
                        newMessage.from = page.pageUser
                        newMessage.dayStarter = dayStarter
                        newMessage.createdTime = createdDate
                        newMessage.opened = true
                        newMessage.conversation = conversation
                        
                        do {
                            Task {
                                try self.moc.save()
                            }
                            //self.messages.append(newMessage)
                        } catch {
                            print("Error saving sent message data: \(error.localizedDescription)")
                        }
                        completion(sentMessageData!)
                    }
                    else {
                        print("Message ID is nil")
                        completion(["error": ["message": "Message ID could not be resolved"]])
                    }
                    
                }
                else {
                    completion(["error": ["message": "Could not encode message data"]])
                }
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
    let messageToScrollTo: Message?
    let fromCorrespondentSearch: Bool
    @ObservedObject var correspondent: MetaUser
    
    init(width: CGFloat, currentMessage: Message, conversation: Conversation, page: MetaPage, messageToScrollTo: Message? = nil, fromCorrespondentSearch: Bool) {
        self.conversation = conversation
        self.width = width
        self.page = page
        self.currentMessage = currentMessage
        self.correspondent = conversation.correspondent!
        self.messageToScrollTo = messageToScrollTo
        self.fromCorrespondentSearch = fromCorrespondentSearch
    }
    
    var body: some View {
        let isCurrentUser = page.businessAccountID == currentMessage.from?.id || page.id == currentMessage.from?.id
        let dates = Calendar.current.dateComponents([.hour, .minute], from: currentMessage.createdTime!)
        let highlight: Bool = !self.fromCorrespondentSearch && self.messageToScrollTo?.uid == currentMessage.uid
        if !isCurrentUser {
            VStack(spacing: 1) {
                HStack {
                    AsyncImage(url: self.correspondent.profilePictureURL ?? URL(string: "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("Purple")) } .frame(width: 25, height: 25, alignment: .bottom) .clipShape(Circle()).padding(.leading).onTapGesture {
                            openProfile(correspondent: correspondent)
                    }
                    MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser, highlight: highlight)
                }.frame(width: width * 0.875, alignment: .leading).padding(.trailing).offset(x: -20)
                
                Text("\(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")")
                    .frame(width: width * 0.875, alignment: .leading).padding(.trailing)
                    .font(Font.custom(REGULAR_FONT, size: 9))
                    .foregroundColor(.gray)
            }
        }
        else {
            VStack(spacing: 1) {
                MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser, highlight: highlight)
                    .frame(width: width * 0.875, alignment: .trailing).padding(.leading).padding(.trailing)
                Text("\(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")")
                    .frame(width: width * 0.875, alignment: .trailing).padding(.leading).padding(.trailing)
                    .font(Font.custom(REGULAR_FONT, size: 9))
                    .foregroundColor(.gray)
            }
        }
    }
}


//"https://www.facebook.com/dialog/oauth?response_type=token&display=popup&client_id=1095098671184689&redirect_uri=https%3A%2F%2Fdevelopers.facebook.com%2Ftools%2Fexplorer%2Fcallback%3Fbusiness_id%3D857648335336354&scope=instagram_manage_messages%2Cpages_manage_metadata%2Cinstagram_basic"


func openProfile(correspondent: MetaUser) {
    var hook = ""
    switch correspondent.platform {
        case "instagram":
            hook = "instagram://user?username=\(correspondent.username!)"
        case "facebook":
            hook = "fb://profile/\(correspondent.email!)"
        default:
            hook = ""
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
                    
                    if contentMessage.instagramStoryReply!.cdnURL != nil {
                        AsyncImage(url: contentMessage.instagramStoryReply!.cdnURL!) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("Purple")) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
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
            Text(contentMessage.message!)
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
                
                if contentMessage.instagramStoryMention!.cdnURL != nil {
                    AsyncImage(url: contentMessage.instagramStoryMention!.cdnURL!) { image in image.resizable() } placeholder: { LottieView(name: "Loading-2").frame(width: 50, height: 50, alignment: .leading) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
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
        AsyncImage(url: contentMessage.imageAttachment!.url ?? URL(string: "")) {
            image in
            image.resizable()
        } placeholder: {
            LottieView(name: "Loading-2").frame(width: 50, height: 50, alignment: .leading)
        }.frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                self.session.fullScreenImageUrlString = contentMessage.imageAttachment!.url?.absoluteString
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
        let url = contentMessage.videoAttachment!.url ?? URL(string: "")
        
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
    @Environment(\.colorScheme) var colorScheme
    let contentMessage: Message
    let isCurrentUser: Bool
    var highlight: Bool

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
                        Text(contentMessage.message!)
                            .padding(10)
                            .foregroundColor(isCurrentUser ? Color.white : Color.black)
                            .background(isCurrentUser ? Color("Purple") : Color.offWhite)
                            .cornerRadius(10)
                            .font(Font.custom(REGULAR_FONT, size: 17))
                            .if(self.highlight) { view in
                                view
                                
                                .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isCurrentUser ? Color.yellow : Color("Purple"), lineWidth: 4)
                                )
                        }
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
    typealias Value = CGFloat
    typealias Transform = ViewHeightKeyTransform

    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}


struct ViewHeightKeyTransform: PreferenceKey {
    typealias Value = CGRect?
    typealias Transform = ViewHeightKeyTransform

    static var defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }

    static func transformPreference(_ value: inout Value, _ nextValue: () -> Value) {
        value = nextValue()
    }
}


func sortMessages(messages: [Message]) -> [Message] {
    return messages.sorted {$0.createdTime! < $1.createdTime!}
}


func convertToDictionary(text: String) -> [String: Any]? {
    if let data = text.data(using: .utf8) {
        print("GOT DATA")
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("JSON ERROR")
            print(error.localizedDescription)
        }
    }
    print("DID NOT GET DATA")
    return nil
}


func getRequestResponse(urlString: String, header: [String: String]? = nil) async -> (HTTPURLResponse?, Data?)? {
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
        return (httpResponse, data)
      }
      catch {
          return nil
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


func postRequestJSON(urlString: String, data: Data, completion: @escaping ([String: AnyObject]?) -> Void) {
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    request.httpBody = data
    
    let dataTask = URLSession.shared.dataTask(with: request) {(data, response, error) in
        if let error = error {
            print("Request error:", error)
            completion(nil)
        }
        
        guard let data = data else {
            print("Couldn't get data")
            completion(nil)
            return
        }

        do {
            if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                completion(jsonDataDict)
            }
            else {
                print("Couldn't deserialize data")
                completion(nil)
            }
        }
        
        catch let error as NSError {
            print(error)
            completion(nil)
        }
    }
    dataTask.resume()
}

func postRequestXForm(urlString: String, completion: @escaping ([String: AnyObject]?) -> Void) {
    print(urlString)
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let dataTask = URLSession.shared.dataTask(with: request) {(data, response, error) in
        if let error = error {
            print("Request error:", error)
            completion(nil)
        }
        
        guard let data = data else {
            print("Couldn't get data")
            completion(nil)
            return
        }

        do {
            if let jsonDataDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                completion(jsonDataDict)
            }
            else {
                print("Couldn't deserialize data")
                completion(nil)
            }
        }
        
        catch let error as NSError {
            print(error)
            completion(nil)
        }
    }
    dataTask.resume()
}


func initializePage(page: MetaPage) {
    let db = Firestore.firestore()
    
    let pageDoc = db.collection(Pages.name).document(page.id!)
    pageDoc.getDocument() {
        doc, error in
        if error == nil && doc != nil {
            if !doc!.exists {
                db.collection(Pages.name).document(page.id!).setData(
                    [
                        Pages.fields.INSTAGRAM_ID: page.businessAccountID,
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
                    Pages.fields.INSTAGRAM_ID: page.businessAccountID,
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


// EAAPjZCIdKOzEBAAFGha2IfCQtZCovoAvXsBKUJGKa6i7dWTF8Jj1z9j1mXTMo8iDOJXQxnsZCXoIvKa1LMSx35tHP37CZBDugNZAW99DXcaCTVa6OZAJv4QfkLbGhaslGWvHF9k2tSzBxq2uszgMm7BU56VEUhWSTt8mOsON6me4kveHuWnh798YNsfnZCSulBq5EKbLD9mHxGLDXtHznGYt1ZCKsfB3IplTDW0U4FZCvonoUmZCLiJElLcR6hHy9BTj6ZA7PubAmZBtygZDZD


//curl -X POST \
//  -F 'subscribed_fields="messages"' \
//  -F 'access_token=EAAPjZCIdKOzEBAONwvMuQgmIzX3t9LWaRrB8XZCsZBFVZBdYCOh31PSVmFQybe2LPsbBhy3S6MTZA4sCqcCkj8TgMivRljuD0TjtyiZAWzQKSKehmF6FtpaWdsavkXT4OIcoGaMRMNPZBoh2WpDFwjdnCZCc3wFKYCqcC4bWqpxe9KZAJbAnhX4IR7JTtTwmAxDw4GJld06o9ZCcKuUIaKg3iXITBYonm8v5sZD' \
//  https://graph.facebook.com/v16.0/{page-id}/subscribed_apps

//https://graph.facebook.com/v16.0/106484141882461?fields=instagram_business_account&access_token=
