//
//  ContentView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI
import FBSDKLoginKit

struct ContentView: View {
    @EnvironmentObject var session: SessionStore
    @State var showingMenu: Bool = false
    @State private var selection = 1
    let loginManager = LoginManager()
    
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
                                    VStack {
    
                                        Image(systemName: "line.3.horizontal").font(.system(size: 25)).onTapGesture(perform: {
                                            withAnimation {self.showingMenu.toggle()}
                                        }).frame(width: geometry.size.width, height: geometry.size.height * 0.05, alignment: .leading).padding(.leading)
    
                                        TabView(selection: self.$selection) {
                                            InboxView().environmentObject(self.session)
                                                .tabItem {
                                                    Label("Inbox", systemImage: "mail.stack.fill")
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
                                            
                                        }.ignoresSafeArea(.keyboard).frame(height: geometry.size.height * 0.95)
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
