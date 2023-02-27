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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                ForEach(self.session.availablePages, id: \.self) {
                    page in
                    HStack {
                        Text(page.name).font(.system(size: 25)).frame(width: width * 0.80, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                            self.session.selectedPage = page
                        }.padding(.leading)
                        if page == self.session.selectedPage {
                            Image(systemName: "checkmark.circle").font(.system(size: 25)).frame(width: width * 0.20, alignment: .leading)
                        }
                        else {
                            Spacer()
                        }
                    }
                }
            }
        }.frame(height: height).offset(y: 45)
    }
}
