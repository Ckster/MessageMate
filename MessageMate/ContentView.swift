//
//  ContentView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI
import FBSDKLoginKit
import FirebaseFirestore


struct FooAnchorData: Equatable {
    var anchor: Anchor<CGRect>? = nil
    static func == (lhs: FooAnchorData, rhs: FooAnchorData) -> Bool {
        return false
    }
}


struct FooAnchorPreferenceKey: PreferenceKey {
    static let defaultValue = FooAnchorData()
    static func reduce(value: inout FooAnchorData, nextValue: () -> FooAnchorData) {
        value.anchor = nextValue().anchor ?? value.anchor
    }
}


struct ContentView: View {
    let db = Firestore.firestore()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var moc
    @EnvironmentObject var session: SessionStore
    var tabsCount: CGFloat = 3
    var badgePosition: CGFloat = 2
    let loginManager = LoginManager()
    @ObservedObject var pushNotificationState = PushNotificationState.shared
    @ObservedObject var tabSelectionState = TabSelectionState.shared
    @State var testString: String = ""
    
    @FetchRequest(sortDescriptors: []) var conversationsHook: FetchedResults<Conversation>
    
    @State var pagesToUpdate: [MetaPageModel]? { didSet { self.writeNewPages() } }
    @State var conversationsToUpdate: [ConversationModel]? { didSet { self.writeNewConversations() } }
    @State var messagesToUpdate: [MessageModel]? { didSet { self.writeNewMessages() } }
    
    init() {
        UINavigationBar.appearance().barTintColor = .lightGray
    }
    
    var body: some View {
        GeometryReader { geometry in
            if self.session.isLoggedIn == .loading {
                LogoView(width: geometry.size.width, height: geometry.size.height).frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }

            if self.session.isLoggedIn == .signedIn {
                Group {
                switch self.session.onboardingCompleted {

                case nil:
                    Text("Discerning onboarding status ...")
                        .onAppear(perform: {
                            self.session.getOnboardingStatus()
                        })

                case true:
                    ZStack {
                        ZStack(alignment: .bottomLeading) {

                            AuthedView(width: geometry.size.width, height: geometry.size.height, contentView: self)
                                .environmentObject(self.session)
                                .environment(\.managedObjectContext, self.moc)

                            if self.session.unreadMessages > 0 {
                                // Have to add all this in so keyboard avoidance works
                                VStack {
                                    Spacer()
                                    Image(systemName: "\(self.session.unreadMessages).circle").ignoresSafeArea(.keyboard).foregroundColor(Color.red).font(.system(size: 14))
                                        .offset(x: ( ( 2 * self.badgePosition ) - 1 ) * ( geometry.size.width / ( 2 * self.tabsCount ) ) + 8, y: -35)
                                        .opacity(self.session.unreadMessages == 0 ? 0 : 1)
                                }.ignoresSafeArea(.keyboard)
                            }
                        }
                    }
                    // When a user taps on a conversation message notification navigate to the inbox
                    .onReceive(self.pushNotificationState.$conversationToNavigateTo, perform: {
                        conversation in
                        if conversation != nil {
                            DispatchQueue.main.async {
                                self.tabSelectionState.selectedTab = 2
                            }
                        }
                    })

                case false:
                    OnboardingView(contentView: self)
                        .environmentObject(self.session)
                        .environment(\.managedObjectContext, self.moc)

                default :
                    Text("Discerning onboarding status ...")
                }

            }
        }

        if self.session.isLoggedIn == .signedOut {
            SignInView().environmentObject(self.session)
        }
    }.onChange(of: self.session.facebookUserToken, perform: { newToken in
        if newToken != nil {
            print("Initializing page info")
            self.initializePageInfo()
        }
    })
}
}


struct AuthedView: View {
    @Environment(\.managedObjectContext) var moc
    @EnvironmentObject var session: SessionStore
    @ObservedObject var tabSelectionState = TabSelectionState.shared
    
    let width: CGFloat
    let height: CGFloat
    
    let contentView: ContentView
    
    var body: some View {
        
        TabView(selection: self.$tabSelectionState.selectedTab) {
            BusinessInformationView().environmentObject(self.session)
                .tabItem {
                    Label("Business Info", systemImage: "building.2.crop.circle.fill")
                }
                .tag(1)

            InboxView(contentView: contentView)
                .environmentObject(self.session)
                .tabItem {
                    var text = "Inbox"
                    Label(text, systemImage: "mail.stack.fill")
                }
                .tag(2)
                .environment(\.managedObjectContext, self.moc)

            AccountView(width: width, height: height, contentView: contentView).environmentObject(self.session)
                .tabItem {
                    var text = "Account"
                    Label(text, systemImage: "person.crop.circle.fill")
                }
                .tag(3)

        }.ignoresSafeArea(.keyboard)
            .accentColor(Color("Purple"))
    }
    
}
