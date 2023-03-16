//
//  TestView.swift
//  MessageMate
//
//  Created by Erick Verleye on 3/15/23.
//

import SwiftUI
import AVKit

struct TestView: View {
    @State var playing: Bool = false
    @State var fullScreen: Bool = false
    @State var offset = CGSize.zero
    
    let height: CGFloat
    let width: CGFloat
        
    var body: some View {
            let url = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4" ?? "")
        
            if url != nil {
                let player = AVPlayer(url: url!)
                
                if self.fullScreen {
                    VStack {
                        Image(systemName: "xmark").font(.system(size: 30)).frame(width: width, alignment: .leading).onTapGesture {
                            self.fullScreen = false
                            player.pause()
                        }.padding(.bottom).padding(.leading)
                        
                        VideoPlayer(player: player)
                            .frame(height: 1000).frame(width: 400, height: 600, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .onAppear(perform: {
                                player.play()
                            })
                    }
                    .transition(AnyTransition.scale.animation(.easeInOut(duration: 1)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { _ in
                                if abs(offset.height) > 100 {
                                    player.pause()
                                    offset = .zero
                                    self.fullScreen = false
                                } else {
                                    offset = .zero
                                }
                            }
                    )
                }
                else {
                    VideoPlayer(player: player)
                        .frame(height: 400).frame(width: 150, height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture {
                            self.fullScreen = true
                        }
                }
                
            }
    }
}

