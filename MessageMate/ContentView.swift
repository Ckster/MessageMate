//
//  ContentView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI
import FBSDKLoginKit


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
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var showingMenu: Bool = false
    @State private var selection = 1
    var tabsCount: CGFloat = 3
    var badgePosition: CGFloat = 1
    let loginManager = LoginManager()
    
//    init() {
//        UITabBar.appearance().barTintColor = self.colorScheme == .light ? UIColor(Color.black) : UIColor(Color.black)
//    }
    
    var body: some View {
            if self.session.isLoggedIn == .loading {
                LottieView(name: "97952-loading-animation-blue")
                    }
    
            if self.session.isLoggedIn == .signedIn {
                Group {
                    GeometryReader { geometry in
                        // Set the drag to control the menu UI
                        let drag = DragGesture().onEnded {
                            if !self.showingMenu {
                                if $0.translation.width > 20 {
                                    print(1)
                                    withAnimation {
                                        self.showingMenu = true
                                    }
                                }
                            }
                            if self.showingMenu {
                                if $0.translation.width < -100 {
                                    print(2)
                                    withAnimation {
                                        self.showingMenu = false
                                    }
                                }
                            }
                        }
    
                        switch self.session.onboardingCompleted {
                            case nil:
                            Text("Discerning onboarding status ...")
                                .onAppear(perform: {
                                    self.session.getOnboardingStatus()
                                })
    
                            case true:
                                ZStack {
                                    ZStack(alignment: .bottomLeading) {
                                        TabView(selection: self.$selection) {
                                            InboxView().environmentObject(self.session)
                                                .tabItem {
                                                    var text = "Inbox"
                                                    Label(text, systemImage: "mail.stack.fill")
                                                }
                                                .tag(1)
                                                
    
                                            TutorialView().environmentObject(self.session)
                                                .tabItem {
                                                    Label("Instructions", systemImage: "graduationcap.circle.fill")
                                                }
                                                .tag(2)
    
                                            BusinessInformationView().environmentObject(self.session)
                                                .tabItem {
                                                    Label("Business Info", systemImage: "building.2.crop.circle.fill")
                                                }
                                                .tag(3)
                                            
                                        }.ignoresSafeArea(.keyboard)
                                            .accentColor(Color("aoBlue"))
                                        
                                        if self.session.unreadMessages > 0 {
                                            Image(systemName: "\(self.session.unreadMessages).circle").foregroundColor(Color.red).font(.system(size: 14))
                                                .offset(x: ( ( 2 * self.badgePosition ) - 1 ) * ( geometry.size.width / ( 2 * self.tabsCount ) ) + 8, y: -35)
                                                .opacity(self.session.unreadMessages == 0 ? 0 : 1)
                                        }
                                    }
                                    .disabled(self.showingMenu ? true : false)
    
                                    if self.showingMenu {
                                        HStack {
                                            MenuView(width: geometry.size.width, height: geometry.size.height)
                                            .frame(width: geometry.size.width * 0.65, height: geometry.size.height).transition(.move(edge: .leading))
                
                                            Color.black.opacity(0.00001).frame(width: geometry.size.width * 0.35, height: geometry.size.height).transition(.move(edge: .leading)).onTapGesture {
                                                if self.showingMenu {
                                                    withAnimation {
                                                        self.showingMenu = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }.gesture(drag)
    
                            case false:
                                OnboardingView().environmentObject(self.session)
    
                            default :
                                Text("Discerning onboarding status ...")
                            }
                        }
                    }
    //            .onReceive(self.session.profileInformation!.$minimumInfoObtained, perform: {
    //                    minInfo in
    //                    self.showHomeScreen = minInfo
    //                })
                }
    
            if self.session.isLoggedIn == .signedOut {
                SignInView().environmentObject(self.session)
            }
        }
    }
    
// https://messagemate-2d9af.firebaseapp.com/__/auth/handler
