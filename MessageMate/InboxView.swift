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


// TODO: Add full screen for story mentions and replies
// TODO: Check on local notifcations waking app up from termination
// TODO: Better multi page management
// TODO: Delete account workflow
// TODO: Fix log in after already onboarded
// TODO: Sending old messages not showing up
// TODO: Fix account image
// TODO: Add indication of no business account if there is none in place of account image
// TODO: Search in conversations view / individual conversations

// TODO: Tell people why they are only seeing last 24hr of messages OR
// TODO: Put human tag in POST request after 24 hours

// TODO: Calendar


struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        GeometryReader {
            geometry in
            if !self.session.loadingFacebookUserToken && self.session.facebookUserToken == nil {
                FacebookAuthenticateView(width: geometry.size.width, height: geometry.size.height).environmentObject(self.session)
            }
            else {
                ConversationsView(width: geometry.size.width, height: geometry.size.height, geometryReader: geometry).environmentObject(self.session)
            }
        }
    }
}


struct ConversationsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State var firstAppear: Bool = true
    @State var sortedConvervations: [Conversation]? = nil
    @State var missingFields: [String] = []
    let db = Firestore.firestore()
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    
    var body: some View {
        NavigationView {
          
            VStack(alignment: .leading) {
                Text("Messages").bold().font(Font.custom("Monsterrat-ExtraBold", size: 30)).offset(x: 0).padding(.leading)
                
                if self.session.loadingPageInformation {
                    LottieView(name: "Paperplane")
                }
                
                else {
                    if self.session.selectedPage != nil {
                        
                        Text("You have \(self.session.unreadMessages == 0 ? "no" : String(self.session.unreadMessages)) new \(self.session.unreadMessages != 1 ? "messages" : "message")").foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).padding(.leading).padding(.bottom)
                        
                        ScrollView {
                            
                            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                Task {
                                    // TODO: If we add this feature find a way to not use so many API calls (only get new message info) or for users not to abuse it
                                    await self.session.updateConversations(page: self.session.selectedPage!)
                                }
                            }
                            
                            if self.missingFields.count > 0 {
                                VStack(alignment: .center) {
                                    Image("undraw_add_information_j2wg").resizable().frame(width: width * 0.75, height: height * 0.35).offset(y: 0).padding()
                            
                                    Text("Please go to the business information tab and add information for the following fields before replying to messages :").frame(width: width * 0.75, height: height * 0.25).lineSpacing(7).font(Font.custom(REGULAR_FONT, size: 20)).multilineTextAlignment(.center)
                                    ForEach(self.missingFields, id: \.self) {
                                        field in
                                        Text(field.replacingOccurrences(of: "_", with: " ").capitalized)
                                    }
                                }
                            }
                            
                            else {
                                if self.session.selectedPage!.conversations.count == 0 {
                                    Text("No conversations. Pull down to refresh.").font(Font.custom(REGULAR_FONT, size: 30))
                                }
                                
                                else {
                                    @State var sortedConversations = self.session.selectedPage!.conversations.sorted {$0.messages.last?.createdTime ?? Date() > $1.messages.last?.createdTime ?? Date()}
                                    ForEach(sortedConversations, id:\.self) { conversation in
                                        if conversation.messages.count > 0 {
                                            ConversationNavigationView(conversation: conversation, width: width, height: height, geometryReader: self.geometryReader, page: self.session.selectedPage!).environmentObject(self.session)
                                        }
                                        else {
                                            Text("").onAppear(perform: {print(conversation.id, "no messages")})
                                            
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
                    }
                        
                    else {
                        NoBusinessAccountsLinkedView(width: width, height: height).environmentObject(self.session).onChange(of: self.session.facebookUserToken, perform: { newToken in
                            self.session.getPageInfo() {}
                        })
                    }
                }
            }
        }
        .accentColor(Color("Purple"))
        // TODO: Add / remove listeners when page changes
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


struct ConversationNavigationView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var conversation: Conversation
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    let page: MetaPage
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var correspondent: MetaUser
    @ObservedObject var pushNotificationState = PushNotificationState.shared
    @State var navigate: Bool = false
    
    init(conversation: Conversation, width: CGFloat, height: CGFloat, geometryReader: GeometryProxy, page: MetaPage) {
        self.conversation = conversation
        self.width = width
        self.height = height
        self.geometryReader = geometryReader
        self.page = page
        self.correspondent = conversation.correspondent!
    }
    
    var body: some View {
        VStack {
            let navTitle = conversation.correspondent?.name ?? conversation.correspondent?.username ?? conversation.correspondent?.email ?? ""
            
            NavigationLink(destination: ConversationView(conversation: conversation, page: page, navigate: self.$navigate, width: width, height: height, geometryReader: self.geometryReader).environmentObject(self.session)
                .navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem {
                        HStack {
                            HStack {
                                AsyncImage(url: URL(string: conversation.correspondent?.profilePicURL ?? "")) { image in image.resizable() } placeholder: { EmptyView() } .frame(width: 37.5, height: 37.5) .overlay(
                                    Circle()
                                        .stroke(Color("Purple"), lineWidth: 3)
                                ).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 0.5) {
                                    Text(navTitle).font(Font.custom(BOLD_FONT, size: 18))
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
                        AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("Purple")).font(.system(size: 50)) } .frame(width: 55, height: 55).overlay(
                            Circle()
                                .stroke(Color("Purple"), lineWidth: 3)
                        ).clipShape(Circle()).offset(y: conversation.messages.last!.message == "" ? -6 : 0)
                        
                        VStack(spacing: 0.5) {
                            HStack {
                                Text(navTitle).foregroundColor(self.colorScheme == .dark ? .white : .black).font(Font.custom(REGULAR_FONT, size: 22)).lineLimit(1)
                                Image(self.correspondent.platform == .instagram ? "instagram_logo" : "facebook_logo").resizable().frame(width: 15.5, height: 15.5)
                            }.frame(width: width * 0.55, alignment: .leading)
                        
                            HStack {
                                if conversation.messages.last!.instagramStoryMention != nil {
                                    Text("\(conversation.correspondent?.name ?? "") mentioned you in their story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                }
                                else {
                                    
                                    if conversation.messages.last!.imageAttachment != nil {
                                        Text("\(conversation.correspondent?.name ?? "") sent you an image").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                    }
                                    
                                    else {
                                        
                                        if conversation.messages.last!.instagramStoryReply != nil {
                                            Text("\(conversation.correspondent?.name ?? "") replied to your story").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                        }
                                        
                                        else {
                                            
                                            if conversation.messages.last!.videoAttachment != nil {
                                                Text("\(conversation.correspondent?.name ?? "") sent you a video").lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                            }
                                            
                                            else {
                                                Text((conversation.messages.last!).message).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15)).frame(width: width * 0.55, alignment: .leading)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        let lastMessageIntervalString = self.makeTimeElapsedString(elapsedTime: conversation.messages.last!.createdTime.timeIntervalSinceNow)
                        Text(lastMessageIntervalString).lineLimit(1).multilineTextAlignment(.leading).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 10)).frame(width: width * 0.20)
                        
                    }
                    
                    if !conversation.messages.last!.opened {
                        HStack(spacing: 0) {
                            Color("Purple").frame(width: width * 0.01, height: 75)
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
    @ObservedObject var conversation: Conversation
    
    let height: CGFloat
    let width: CGFloat
    let page: MetaPage
    let geometryReader: GeometryProxy
        
    var body: some View {
            VStack {
                
                DynamicHeightTextBox(typingMessage: self.$typingMessage, messageSendError: self.$messageSendError, height: height, width: width, conversation: conversation, page: page, geometryReader: geometryReader).frame(width: width * 0.925).environmentObject(self.session)
                
                Spacer()
                HStack(spacing: 2) {
                    
                    DeleteTypingTextButton(width: self.width, height: self.height, typingText: self.$typingMessage)
                            
                    AutoGenerateButton(buttonText: "Respond", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
            
                    AutoGenerateButton(buttonText: "Sell", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
          
                    AutoGenerateButton(buttonText: "Yes", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
                                
                    AutoGenerateButton(buttonText: "No", width: width, height: height, conversationId: self.conversation.id, pageAccessToken: self.page.accessToken, pageName: self.page.name, accountId: self.page.id, typingText: self.$typingMessage, showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse).environmentObject(self.session)
                    
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
    
    let width: CGFloat
    let height: CGFloat
    let geometryReader: GeometryProxy
    
   // @Binding var openMessages: Bool
    
    var maxHeight : CGFloat = 250
    
    let page: MetaPage

    init(conversation: Conversation, page: MetaPage, navigate: Binding<Bool>, width: CGFloat, height: CGFloat, geometryReader: GeometryProxy) {
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
    }
    
    var body: some View {
            
            ZStack {
                VStack {
                    
//                    MessageThreadView(typingMessage: self.$typingMessage, conversation: self.conversation, height: height, width: width, page: page).onTapGesture {
//                        self.messageIsFocused = false
//                    }
                    
                    TextControlView(showCouldNotGenerateResponse: self.$showCouldNotGenerateResponse, messageSendError: self.$messageSendError, typingMessage: self.$typingMessage, conversation: self.conversation, height: height, width: width, page: page, geometryReader: geometryReader).focused($messageIsFocused).onDisappear(perform: {
                        print("ON DISAPPEAR")
                        self.session.selectedPage!.sortConversations()
                    }).environmentObject(self.session)
                    
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
    @FocusState var textEditorIsFocused: Bool

    let height: CGFloat
    let width: CGFloat
    let conversation: Conversation
    let page: MetaPage
    let geometryReader: GeometryProxy
    
    var body: some View {
        ZStack {
            VStack {
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
                        }.onChange(of: textEditorIsFocused) {
                            _ in
                            value.scrollTo(conversation.messages.last?.id)
                        }
                        .onAppear(perform: {
                            value.scrollTo(conversation.messages.last?.id)
                        })
                    }
                }
                .frame(height: max(50, geometryReader.size.height - textEditorHeight - 200))
                .onTapGesture {
                    self.textEditorIsFocused = false
                }
                Spacer()
            }
            //.frame(height: max(0, geometryReader.size.height - pow(textEditorHeight, 1) - 150))
            
            VStack {
                Spacer()
                
                if self.session.autoGeneratingMessage {
                    LottieView(name: "Loading-2").frame(width: width, height: height * 0.10, alignment: .leading)
                }
                
                else {
                    HStack {
                        
                        ZStack(alignment: .bottomLeading) {
                            Text(typingMessage)
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
                                .frame(height: textEditorHeight)
                                .background(self.colorScheme == .dark ? Color.black : Color.white)
                                .focused(self.$textEditorIsFocused)
                        }.frame(width: width * 0.85)
                        
                        VStack {
                            Spacer()
                            
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
                                Image(systemName: "paperplane.circle")
                                    .offset(x: -5, y: self.typingMessage != "" ? -3 : -1)
                                    .font(.system(size: 35))
                                //.position(x: width * 0.85, y: 10)
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
    
    func sendMessage(message: String, to: MetaUser, completion: @escaping ([String: Any]) -> Void) {
        /// API Reference: https://developers.facebook.com/docs/messenger-platform/reference/send-api/
        let urlString = "https://graph.facebook.com/v16.0/\(page.id)/messages?access_token=\(page.accessToken)"
        let data: [String: Any] = ["recipient": ["id": to.id], "message": ["text": message]]
        let jsonData = try? JSONSerialization.data(withJSONObject: data)
        
        if jsonData != nil {
            print("Message Data not Nil")
            postRequestJSON(urlString: urlString, data: jsonData!) {
                sentMessageData in
                if sentMessageData != nil {
                    let messageId = sentMessageData!["message_id"] as? String
                
                    if messageId != nil {
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
                    }
                    completion(sentMessageData!)
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
                    AsyncImage(url: URL(string: self.correspondent.profilePicURL ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("Purple")) } .frame(width: 25, height: 25, alignment: .bottom) .clipShape(Circle()).padding(.leading).onTapGesture {
                            openProfile(correspondent: correspondent)
                    }
                    MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser)
                }.frame(width: width * 0.875, alignment: .leading).padding(.trailing).offset(x: -20)
                
                Text("\(dates.hour! > 12 ? dates.hour! - 12 : dates.hour!):\(String(format: "%02d", dates.minute!)) \(dates.hour! > 12 ? "PM" : "AM")")
                    .frame(width: width * 0.875, alignment: .leading).padding(.trailing)
                    .font(Font.custom(REGULAR_FONT, size: 9))
                    .foregroundColor(.gray)
            }
        }
        else {
            VStack(spacing: 1) {
                MessageBlurbView(contentMessage: currentMessage, isCurrentUser: isCurrentUser)
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
                        AsyncImage(url: URL(string: contentMessage.instagramStoryReply!.cdnUrl ?? "")) { image in image.resizable() } placeholder: { Image(systemName: "person.circle").foregroundColor(Color("Purple")) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
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
                    AsyncImage(url: URL(string: contentMessage.instagramStoryMention!.cdnUrl ?? "")) { image in image.resizable() } placeholder: { LottieView(name: "Loading-2").frame(width: 50, height: 50, alignment: .leading) } .frame(width: 150, height: 250).clipShape(RoundedRectangle(cornerRadius: 16))
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
            LottieView(name: "Loading-2").frame(width: 50, height: 50, alignment: .leading)
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
    @Environment(\.colorScheme) var colorScheme
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
                            .background(isCurrentUser ? Color("Purple") : Color.offWhite)
                            .cornerRadius(10)
                            .font(Font.custom(REGULAR_FONT, size: 17))
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
        
        let responseData: (HTTPURLResponse?, Data?)? = await getRequestResponse(urlString: urlString)
        var returnId: String? = nil
        if responseData != nil {
            let header = responseData!.0
            let data = responseData!.1
            
            if header != nil {
                // First look in the use case header field
                let headerJson = header!.allHeaderFields[AnyHashable("x-business-use-case-usage")] as? String
                if headerJson != nil {
                    let businessUseCase = convertToDictionary(text: headerJson!)
                    if businessUseCase != nil {
                        for accountId in businessUseCase!.keys {
                            let valueDict = businessUseCase![accountId] as? [[String: Any]]
                            if valueDict != nil {
                                let typeDict = valueDict!.first
                                if typeDict != nil {
                                    let type = typeDict!["type"] as? String
                                    if type != nil && type == "instagram" {
                                        returnId = accountId
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Otherwise look in the response data. This should only contain the business account ID for admin pages, because it is not a business use case then
            else {
                if data != nil {
                    do {
                        if let jsonDataDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                            let instaData = jsonDataDict["instagram_business_account"] as? [String: String]
                            if instaData != nil {
                                let id = instaData!["id"]
                                if id != nil {
                                    returnId = id!
                                }
                            }
                        }
                    }
                    catch {
                        
                    }

                }
            }
        }
        self.businessAccountId = returnId
    }
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


// EAAPjZCIdKOzEBAAFGha2IfCQtZCovoAvXsBKUJGKa6i7dWTF8Jj1z9j1mXTMo8iDOJXQxnsZCXoIvKa1LMSx35tHP37CZBDugNZAW99DXcaCTVa6OZAJv4QfkLbGhaslGWvHF9k2tSzBxq2uszgMm7BU56VEUhWSTt8mOsON6me4kveHuWnh798YNsfnZCSulBq5EKbLD9mHxGLDXtHznGYt1ZCKsfB3IplTDW0U4FZCvonoUmZCLiJElLcR6hHy9BTj6ZA7PubAmZBtygZDZD


//curl -X POST \
//  -F 'subscribed_fields="messages"' \
//  -F 'access_token=EAAPjZCIdKOzEBAONwvMuQgmIzX3t9LWaRrB8XZCsZBFVZBdYCOh31PSVmFQybe2LPsbBhy3S6MTZA4sCqcCkj8TgMivRljuD0TjtyiZAWzQKSKehmF6FtpaWdsavkXT4OIcoGaMRMNPZBoh2WpDFwjdnCZCc3wFKYCqcC4bWqpxe9KZAJbAnhX4IR7JTtTwmAxDw4GJld06o9ZCcKuUIaKg3iXITBYonm8v5sZD' \
//  https://graph.facebook.com/v16.0/{page-id}/subscribed_apps

//https://graph.facebook.com/v16.0/106484141882461?fields=instagram_business_account&access_token=
