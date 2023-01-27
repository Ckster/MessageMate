//
//  OnboardingView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore

struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore
    private var db = Firestore.firestore()
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                Text("Congrats, this is your first time using MessageMate. This will be the onboarding page in the future, but for now just press next.").frame(height: geometry.size.height * 0.5, alignment: .center).font(.system(size: 25))
                Text("Next").font(.system(size: 30)).onTapGesture {
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
                .frame(height: geometry.size.height * 0.5, alignment: .center)
            }
        }
        
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
