//
//  LottieView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/7/23.
//

import SwiftUI
import Lottie

/**
 Creates Lottie animations from json file paths
    - Parameters:
        -name: Path to the Lottie animation JSON file
 */
struct LottieView: UIViewRepresentable {
    
    var name: String = ""
    
    func makeUIView(context: UIViewRepresentableContext<LottieView>) -> UIView {
        let view = UIView(frame: .zero)
        let animationView = LottieAnimationView()
        let animation = LottieAnimation.named(self.name)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play()
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        
        return view
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<LottieView>) {
    }
}
