//
//  SelectPageView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/25/23.
//

import SwiftUI

struct SelectPageView: View {
    let width: CGFloat
    let height: CGFloat
    @EnvironmentObject var session: SessionStore
    @State var currentUserPages: [MetaPage]? = nil
    
    let contentView: ContentView
    
    var body: some View {
        if self.currentUserPages == nil {
            LottieView(name: "Loading-2").frame(width: 100, height: 100)
                .onAppear(perform: {
                    print("SP on appear")
                    self.currentUserPages = self.contentView.fetchCurrentUsersPages()
            })
        }
        else {
            VStack {
                if self.currentUserPages!.count == 0 {
                        Image("undraw_account_re_o7id").resizable().frame(width: width * 0.9, height: height * 0.30).offset(y: 0).padding()
                        Text("Please connect a business page to your Facebook account so you can add information about it here").bold().font(Font.custom(REGULAR_FONT, size: 30)).frame(width: width * 0.85, height: height * 0.30, alignment: .leading).multilineTextAlignment(.center).lineSpacing(10)
                }

                else {
                    VStack(spacing: 25) {
                            ForEach(self.currentUserPages!, id: \.self) {
                                page in
                                ZStack {
                                    Text(page.name!).font(Font.custom(REGULAR_FONT, size: 35)).frame(width: width * 0.95, alignment: .leading)
                                    if page == self.session.selectedPage {
                                        Image(systemName: "checkmark.circle").font(.system(size: 35)).foregroundColor(Color("Purple")).frame(width: width * 0.95, alignment: .trailing)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.session.selectedPage = page
                                }
                            }
                    }.frame(height: height)
                }
            }
        }
    }
}
