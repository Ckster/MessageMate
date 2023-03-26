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
        // TODO: If no pages add an indication here
        VStack(spacing: 25) {
                ForEach(self.session.availablePages, id: \.self) {
                    page in
                    ZStack {
                        Text(page.name).font(Font.custom(REGULAR_FONT, size: 35)).frame(width: width * 0.95, alignment: .leading)
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
