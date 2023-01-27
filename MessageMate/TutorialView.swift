//
//  Tutorial.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import WebKit

struct YouTubeView: UIViewRepresentable {
    let videoId: String
    func makeUIView(context: Context) ->  WKWebView {
        return WKWebView()
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let demoURL = URL(string: "https://www.youtube.com/embed/\(videoId)") else { return }
        uiView.scrollView.isScrollEnabled = false
        uiView.load(URLRequest(url: demoURL))
    }
}

struct TutorialView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    
    // TODO: If this screen remains like this then the info needs to be coming from the database / made more maleable
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Text("Instructions").bold().font(.system(size: 30)).multilineTextAlignment(.leading).padding(.leading).padding(.bottom)
                Text("To begin setting up MessageMate...").bold().font(.system(size: 25)).multilineTextAlignment(.leading).padding(.leading).padding(.bottom)
                Text("Please input detailed infromation in the other tabs.").font(.system(size: 20)).multilineTextAlignment(.leading).padding(.leading).padding(.bottom)
                Text("Be sure to only include information specific to your business- MessageMate is smart enough know general information about most businesses.").multilineTextAlignment(.leading).font(.system(size: 20)).padding(.leading).padding(.bottom)
                Text("For example, if you do landscaping, you can assume MessageMate will be able to explain the process of any landscaping service. MessageMate will not know how long your services take, however.").font(.system(size: 20)).multilineTextAlignment(.leading).padding(.leading).padding(.bottom)
                Text("Please watch the video below to learn more:").font(.system(size: 20)).multilineTextAlignment(.leading).padding(.leading).padding(.bottom)
                
                // TODO: Read in the videoId from the database
                YouTubeView(videoId: "Zy72pXUXHSI").frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.33).frame(alignment: .center).padding(.leading)
                
            }.frame(height: geometry.size.height, alignment: .top)
        }
    }
}
