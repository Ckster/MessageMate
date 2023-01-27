//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import Combine

struct InboxView: View {
    @EnvironmentObject var session: SessionStore
    @State var conversations: [Conversation] = []
    @State var loading: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Inbox").bold().font(.system(size: 30)).offset(x: 0).padding(.leading).padding(.bottom)
                    
                    if self.loading {
                        Text("Loading").onAppear(perform: {
                            print("on appear")
                            self.getConversations()
                        })
                    }
                    else {
                        ScrollView {
                            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                                self.loading = true
                                self.getConversations()
                            }
                            if self.conversations.count == 0 {
                                Text("No messages. Pull down to refresh")
                            }
                            else {
                                ForEach(self.conversations, id:\.self) { conversation in
                                    VStack {
                                        NavigationLink(destination: ConversationView(conversation: conversation)) {
                                            HStack {
                                                VStack {
                                                    Text(conversation.correspondent).foregroundColor(self.colorScheme == .dark ? .white : .black).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                                    Text((conversation.messages.first ?? Message(text: "", selfSent: false)).text).foregroundColor(.gray).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                                }
                                                
                                                Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
                                            }
                                        }
                                        HorizontalLine(color: .gray, height: 0.75)
                                    }.padding(.leading).offset(x: -geometry.size.width * 0.03)
                                }
                            }
                        }.coordinateSpace(name: "pullToRefresh")
                    }
                }
            }
        }
    }
    
    func getConversations() {
        // TODO: Just dummy conversations for now
        self.conversations = [
            Conversation(correspondent: "Jessica", messages: [
                Message(text: "hey! I am wondering about lip blush", selfSent: false)
            ]),
            Conversation(correspondent: "Megan", messages: [
                Message(text: "How much is ombre borws?", selfSent: false)
            ]),
            Conversation(correspondent: "Janeen", messages: [
                Message(text: "Hey girl!", selfSent: false)
            ]),
            Conversation(correspondent: "Pippa", messages: [
                Message(text: "Do you have any sales rn?", selfSent: false),
                Message(text: "No", selfSent: true),
                Message(text: "Do you have any sales r?", selfSent: false),
                Message(text: "Do you have any sales ?", selfSent: false),
                Message(text: "Do you have any sales?", selfSent: false),
                Message(text: "Do you have any sale?", selfSent: false),
                Message(text: "Do you have any sal?", selfSent: false),
                Message(text: "Do you have any sa?", selfSent: false),
                Message(text: "Do you have any s?", selfSent: false),
                Message(text: "Do you have any ?", selfSent: false),
                Message(text: "Do you have an?", selfSent: false),
                Message(text: "Do you have a?", selfSent: false),
                Message(text: "Do you have ?", selfSent: false),
                Message(text: "Do you have", selfSent: false),
                Message(text: "Do you have any sales rn", selfSent: false),
                Message(text: "Do you have any sal", selfSent: false),
                Message(text: "Do you have any sale", selfSent: false),
                Message(text: "Do you have any sale", selfSent: false),
                Message(text: "Do you have any sale", selfSent: false)
            ])
        ]
        self.loading = false
    }
}

class Message: Hashable, Equatable {
    let id = UUID()
    let text: String
    
    // TODO: Change this to some type of User class and add information to hash the messages
    let selfSent: Bool
    
    init (text: String, selfSent: Bool) {
        self.text = text
        self.selfSent = selfSent
    }
    
    func hash(into hasher: inout Hasher) {
        
        // TODO: This is not good / sustainable... when the Messenger API gets hooked up make this the correspondents unique Facebook ID or something
        hasher.combine(self.id)
    }
    
    static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

class Conversation: Hashable, Equatable {
    let correspondent: String
    
    // TODO: Make a Message class instead of using strings, so can add who sent the message etc.
    let messages: [Message]
    
    init(correspondent: String, messages: [Message]) {
        self.correspondent = correspondent
        self.messages = messages
    }
    
    func hash(into hasher: inout Hasher) {
        
        // TODO: This is not good / sustainable... when the Messenger API gets hooked up make this the correspondents unique Facebook ID or something
        hasher.combine(self.correspondent + (self.messages.first ?? Message(text: "", selfSent: false)).text)
    }
    
    static func ==(lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.correspondent == rhs.correspondent
    }
}

struct ConversationView: View {
    let conversation: Conversation
    @State var typingMessage: String = ""
    @State var yPosition: CGFloat = 0
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                ScrollView {
                    ScrollViewReader {
                        value in
                        VStack {
                            ForEach(conversation.messages, id: \.self.id) { msg in
                                MessageView(width: geometry.size.width, currentMessage: msg).id(msg.id)
                            }
                        }.onChange(of: yPosition) { _ in
                            print("YUH")
                            value.scrollTo(conversation.messages.last?.id)
                        }.onAppear(perform: {
                            value.scrollTo(conversation.messages.last?.id)
                        })
                    }
                }
                //.frame(height: geometry.size.height * 0.85)
                
                HStack {
                       TextField("Message...", text: $typingMessage)
                          .textFieldStyle(RoundedBorderTextFieldStyle())
                          //.frame(width: geometry.size.width * 0.70, height: geometry.size.height * 0.05, alignment: .leading)
                        Button(action: sendMessage) {
                            Text("Send")
                                //.frame(width: geometry.size.width * 0.10, height: geometry.size.height * 0.05)
                         }
                }.frame(height: geometry.size.height * 0.15).background(rectReader($yPosition))
            }.navigationTitle(conversation.correspondent).navigationBarTitleDisplayMode(.inline)
        }
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
    var body: some View {
        if !currentMessage.selfSent {
            HStack {
                Image(systemName: "person.circle")
                .resizable()
                .frame(width: 40, height: 40)
                .cornerRadius(20)
                
                MessageBlurbView(contentMessage: currentMessage.text,
                                   isCurrentUser: currentMessage.selfSent)
            }.frame(width: width, alignment: .leading).padding(.leading)
        }
        else {
            MessageBlurbView(contentMessage: currentMessage.text,
                             isCurrentUser: currentMessage.selfSent).frame(width: width * 0.90, alignment: .trailing).padding(.trailing)
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

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: -keyboardHeight)
            .onReceive(Publishers.keyboardHeight) { self.keyboardHeight = $0 }
    }
}


//struct KeyboardAdaptive: ViewModifier {
//    @State private var keyboardHeight: CGFloat = 0
//
//    @State var offset: CGFloat
//
//    func body(content: Content) -> some View {
//        content
//            .offset(y: -keyboardHeight)
//            .onReceive(Publishers.keyboardHeight) {
//                self.keyboardHeight = $0 == 0 ? 0 : $0 - offset
//            }
//    }
//}

extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
}

extension Publishers {
    // 1.
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        // 2.
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }

        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        // 3.
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension Notification {
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
    }
}
