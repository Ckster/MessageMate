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
    let loginManager = LoginManager()
    
    var body: some View {
            if self.session.isLoggedIn == .loading {
                            Text("Loading")
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
    
                                        TabView {
//                                            InboxView().environmentObject(self.session)
//                                                .tabItem {
//                                                    Label("Inbox", systemImage: "mail.stack.fill")
//                                                }
    
                                            TutorialView().environmentObject(self.session)
                                                .tabItem {
                                                    Label("Instructions", systemImage: "graduationcap.circle.fill")
                                                }
    
                                            BusinessInformationView().environmentObject(self.session)
                                                .tabItem {
                                                    Label("Business Info", systemImage: "building.2.crop.circle.fill")
                                            }
                                        }.ignoresSafeArea(.keyboard).frame(height: geometry.size.height * 0.95)
                                    }
                                    .disabled(self.showingMenu ? true : false)
    
                                    if self.showingMenu {
                                        HStack {
                                            MenuView(width: geometry.size.width, height: geometry.size.height)
                                            .frame(width: geometry.size.width * 0.65, height: geometry.size.height).transition(.move(edge: .leading))
                                            //.offset(x: geometry.size.width * -0.175)
    
                                            Color.black.opacity(0.00001).frame(width: geometry.size.width * 0.35, height: geometry.size.height).transition(.move(edge: .leading)).onTapGesture {
                                                if self.showingMenu {
                                                    print(3)
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
    
    struct MenuView: View {
        let width: CGFloat
        let height: CGFloat
        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var session: SessionStore
        @State var showingSignOutAlert: Bool = false
    
        var body: some View {
            let signOutAlert =
                Alert(title: Text("Sign Out"), message: Text("Are you sure you would like to sign out?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Sign Out"), action: {
                    self.session.signOut()
                }))
    
            ZStack {
                Color(self.colorScheme == .dark ? .black : .white)
                HStack {
    
                    VStack(alignment: .leading) {
    
                        Image(systemName: "person.circle").font(.system(size: 60)).imageScale(.large)
                            .padding(.leading)
                        Text(verbatim: "verleyeerick@gmail.com").foregroundColor(.gray).font(.system(size: 15))
                            .padding(.leading)
    
                        Divider()
    
                        HStack {
                            Image(systemName: "info.square").font(.system(size: 30)).padding(.trailing)
                            Text("About").font(.system(size: 25))
                        }.padding(.leading).padding(.bottom)
    
                        HStack {
                            Image(systemName: "arrow.left.to.line.circle").font(.system(size: 30)).padding(.trailing)
                            Text("Sign Out").font(.system(size: 25)).onTapGesture {
                                self.showingSignOutAlert = true
                            }.alert(isPresented: $showingSignOutAlert) {
                                signOutAlert
                            }
                        }.padding(.leading)
    
                        Text("AppInnovations").font(.system(size: 20)).padding(.leading).frame(width: width * 0.65, height: height * 0.70, alignment: .bottom)
    
                    }.frame(height: height)
    
                    Divider()
                }
            }.frame(width: width * 0.65, height: height)
        }
    }
    
// https://messagemate-2d9af.firebaseapp.com/__/auth/handler
