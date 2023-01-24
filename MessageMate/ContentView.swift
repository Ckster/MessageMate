//
//  ContentView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        if self.session.isLoggedIn == .loading {
                        Text("Loading")
                    }

        if self.session.isLoggedIn == .signedIn {
            Group {
                switch self.session.onboardingCompleted {
                    case nil:
                        Text("Loading")
//                        .onAppear(perform: {
//                            self.session.getTutorialStatus()
//                        })
                    
                    case true:
                        TabView {
                            InboxView().environmentObject(self.session)
                                .tabItem {
                                    Label("Inbox", systemImage: "mail.stack.fill")
                                }
                            
                            TutorialView().environmentObject(self.session)
                                .tabItem {
                                    Label("Tutorial", systemImage: "graduationcap.circle.fill")
                                }
                            
                            BusinessInformationView().environmentObject(self.session)
                                .tabItem {
                                    Label("Business Information", systemImage: "building.2.crop.circle.fill")
                                }
                            }
                    
                    case false:
                        OnboardingView().environmentObject(self.session)
                    
                    default :
                        Text("Discerning onboarding status ...")
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// https://messagemate-2d9af.firebaseapp.com/__/auth/handler
