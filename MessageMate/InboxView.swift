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
                    //Text("Inbox").bold().font(.system(size: 30)).offset(x: 0).padding(.leading).padding(.bottom)
                    
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
                                        NavigationLink(destination: ConversationView(conversation: conversation).navigationTitle(conversation.correspondent)) {
                                            HStack {
                                                VStack {
                                                    Text(conversation.correspondent).foregroundColor(self.colorScheme == .dark ? .white : .black).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                                    Text((conversation.messages.first ?? Message(text: "", selfSent: false)).text).foregroundColor(.gray).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                                }
                                                
                                                Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
                                            }
                                        }.navigationBarTitleDisplayMode(.inline).navigationTitle(" ")
//                                            .toolbar {
//                                            ToolbarItem(placement: .principal) {
//                                                // this sets the screen title in the navigation bar, when the screen is visible
//                                                Text("Inbox")
//                                            }
//                                        }
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
    @State var placeholder: Bool = true
    @State var scrollDown: Bool = false
    @State var textEditorHeight : CGFloat = 100
    @FocusState var messageIsFocused: Bool
    var maxHeight : CGFloat = 250
    @EnvironmentObject var session: SessionStore
    
    init(conversation: Conversation) {
        self.conversation = conversation
        
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
                                MessageView(width: geometry.size.width, currentMessage: msg).id(msg.id)
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
                
//                HStack {
//
//                      MessagingUI()
////                    TextView(text: $typingMessage, placeholder: $placeholder)
////                        .overlay(
////                            RoundedRectangle(cornerRadius: 5, style: .continuous)
////                                .strokeBorder(Color.gray, lineWidth: 1.5)
////                        )
////                        .frame(width: geometry.size.width * 0.75, height: geometry.size.height * 0.10, alignment: .leading)
////                        .focused($messageIsFocused)
////                       // .offset(y: 15)
////                        .onTapGesture {
////                            self.placeholder = false
////                            self.scrollDown.toggle()
////                        }.padding(.bottom).padding(.top)
//
//                    Button(action: sendMessage) {
//                        Image(systemName: "paperplane.circle.fill").font(.system(size: 35))
//                    }.frame(width: geometry.size.width * 0.20, alignment: .center)
//
//                }.frame(height: geometry.size.height * 0.15)
                    //.background(rectReader($yPosition))
                
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
                    
//                    Button(action: {}) {
//                        Image(systemName: "plus.circle")
//                            .imageScale(.large)
//                            .foregroundColor(.primary)
//                            .font(.title)
//                    }.padding(15).foregroundColor(.primary)
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
