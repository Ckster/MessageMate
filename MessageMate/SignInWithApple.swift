//
//  SignInWithApple.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//

import SwiftUI
import AuthenticationServices

struct SignInWithApple: UIViewRepresentable {
    var style: ASAuthorizationAppleIDButton.Style

      func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let appleButton = ASAuthorizationAppleIDButton(type: .continue, style: style)
        
        return appleButton
      }

      func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}
