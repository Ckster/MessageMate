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


struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore

    @State var activeView: currentView = .intro
    @State var viewState = CGSize.zero

    private var db = Firestore.firestore()
    
    var body: some View {
        GeometryReader {
            geometry in
            ZStack {
                Text("Foo")
                //intro
//                Foo(color: .blue)
//                    .frame(width: geometry.size.width, height: geometry.size.height)
//                    .offset(x: self.activeView == .intro ? 0 : self.activeView == .info ? -screenWidth : -2 * screenWidth)
//                    .offset(x: self.activeView != .complete ? self.viewState.width : 0)
//                    .animation(.easeInOut)
                //info
//                Foo(color: .red)
//                    .frame(width: geometry.size.width, height: geometry.size.height)
//                    .offset(x: self.activeView == .info ? 0 : self.activeView == .intro ? screenWidth : -screenWidth)
//                    .offset(x: self.viewState.width)
//                    .animation(.easeInOut)
                //complete
//                Foo(color: .green)
//                    .frame(width: geometry.size.width, height: geometry.size.height)
//                    .offset(x: self.activeView == .complete ? 0 : self.activeView == .intro ? screenWidth * 2 : screenWidth)
//                    .offset(x: self.activeView != .intro ? self.viewState.width : 0)
//                    .animation(.easeInOut)
                    
//                    .onTapGesture {
//                    self.db.collection(Users.name).document(self.session.user.user!.uid).updateData([Users.fields.ONBOARDING_COMPLETED: true], completion: {
//                        error in
//                        if error == nil {
//                            self.session.onboardingCompleted = true
//                        }
//                        else {
//                            Text("Oof, there was an error")
//                        }
//                    })
//                }
                
                
            }
        }.gesture(
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

struct IntroView: View {
    let color: Color
    
    var body: some View {
        color.ignoresSafeArea(.all)
    }
    
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
