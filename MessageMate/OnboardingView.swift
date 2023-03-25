//
//  OnboardingView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore


enum currentView {
    case intro
    case info
    case complete
}


let screenSize = UIScreen.main.bounds
let screenWidth = screenSize.width
let screenHeight = screenSize.height

// TODO: In info view sign in with Facebook if not already logged in


struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore

    @State var activeView: currentView = .intro
    @State var viewState = CGSize.zero

    private var db = Firestore.firestore()
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                ZStack {
                    IntroView(width: geometry.size.width, height: geometry.size.height)
                        //.frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: self.activeView == .intro ? 0 : self.activeView == .info ? -screenWidth : -2 * screenWidth)
                        .offset(x: self.activeView != .complete ? self.viewState.width : 0)
                        .animation(.easeInOut)
                    
                    IntroView(width: geometry.size.width, height: geometry.size.height)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: self.activeView == .info ? 0 : self.activeView == .intro ? screenWidth : -screenWidth)
                        .offset(x: self.viewState.width)
                        .animation(.easeInOut)
                    
                    IntroView(width: geometry.size.width, height: geometry.size.height)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: self.activeView == .complete ? 0 : self.activeView == .intro ? screenWidth * 2 : screenWidth)
                        .offset(x: self.activeView != .intro ? self.viewState.width : 0)
                        .animation(.easeInOut)
                        
                        .onTapGesture {
                        self.db.collection(Users.name).document(self.session.user.user!.uid).updateData([Users.fields.ONBOARDING_COMPLETED: true], completion: {
                            error in
                            if error == nil {
                                self.session.onboardingCompleted = true
                            }
                            else {
                                Text("Oof, there was an error")
                            }
                        })
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height * 0.975)
                
                HStack() {
                    Circle()
                        .fill(self.activeView == .intro ? Color("aoBlue") : Color.gray)
                        .frame(width: geometry.size.width * 0.25)
                    Circle()
                        .fill(self.activeView == .info ? Color("aoBlue") : Color.gray)
                        .frame(width: geometry.size.width * 0.25)
                    Circle()
                        .fill(self.activeView == .complete ? Color("aoBlue") : Color.gray)
                        .frame(width: geometry.size.width * 0.25)
                }.frame(width: geometry.size.width * 0.75, height: geometry.size.height * 0.025).offset(y: -40)
            }
            
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        print(value)
                switch self.activeView {
                case .intro:
                    guard value.translation.width < 1 else {return}
                    self.viewState = value.translation
                case .info:
                    self.viewState = value.translation
                case .complete:
                    guard value.translation.width > 1 else {return}
                    self.viewState = value.translation
                }
                    }
                
                    .onEnded {
                        value in
                        print(value)
                        switch self.activeView {
                        case .intro:
                            if value.predictedEndTranslation.width < -screenWidth / 2 {
                                self.activeView = .info
                            }
                            self.viewState = .zero
                            
                        case .complete:
                            if value.predictedEndTranslation.width > screenWidth / 2 {
                                self.activeView = .info
                            }
                            self.viewState = .zero
                        case .info:
                            if value.predictedEndTranslation.width < -screenWidth / 2 {
                                self.activeView = .complete
                            }
                            
                            if value.predictedEndTranslation.width > screenWidth / 2 {
                                self.activeView = .intro
                            }
                            self.viewState = .zero
                        }
                    }
            )
        }
    }
}

struct IntroView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .center) {
            Image("undraw_add_information_j2wg").resizable().frame(width: width * 0.75, height: height * 0.30).offset(y: 0).padding()
            
            Text("Let's Get Started").bold().frame(width: width * 0.75, height: height * 0.07).font(Font.custom("Montserrat-ExtraBold", size: 37)).lineLimit(1)
            
            Text("After adding some basic information about your business you'll be able to generate personalized replies at the click of a button").frame(width: width * 0.6, height: height * 0.20).lineSpacing(7).font(Font.custom("Montserrat-Regular", size: 18)).multilineTextAlignment(.center)
            
                //.offset(y: -50)
            //Spacer()
            //Image(systemName: "arrow.forward").frame(height: height * 0.15).font(.system(size: 35))
        }.offset(y: -100)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
