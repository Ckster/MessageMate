//
//  InboxView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI

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
                                                    Text(conversation.messages.first ?? "").foregroundColor(.gray).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
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
            Conversation(correspondent: "Jessica", messages: ["hey! I am wondering about lip blush"]),
            Conversation(correspondent: "Megan", messages: ["How much is ombre borws?"]),
            Conversation(correspondent: "Janeen", messages: ["Hey girl!"]),
            Conversation(correspondent: "Pippa", messages: ["Do you have any sales rn?"])
        ]
        self.loading = false
    }
}

class Conversation: Hashable, Equatable {
    let correspondent: String
    let messages: [String]
    
    init(correspondent: String, messages: [String]) {
        self.correspondent = correspondent
        self.messages = messages
    }
    
    func hash(into hasher: inout Hasher) {
        
        // TODO: This is not good / sustainable... when the Messenger API gets hooked up make this the correspondents unique Facebook ID or something
        hasher.combine(self.correspondent + (self.messages.first ?? ""))
    }
    
    static func ==(lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.correspondent == rhs.correspondent && lhs.messages.first ?? "" == rhs.messages.first ?? ""
    }
}

struct ConversationView: View {
    let conversation: Conversation
    
    var body: some View {
        VStack {
            Text(self.conversation.correspondent)
            Text("Yo!")
        }
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
