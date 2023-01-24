//
//  BusinessInformationView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI

struct BusinessInformationView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme

    let subViewDict: Dictionary<String, some View> = [
        "Business Inf": BusinessInfoSubView(),
        "Messager Characteristics": BusinessInfoSubView(),
        "Services & Pricing": BusinessInfoSubView(),
        "Frequently Changing": BusinessInfoSubView(),
        "Specific Respsonses": BusinessInfoSubView()
    ]

    var body: some View {
        NavigationView {
            GeometryReader {geometry in
                VStack {
                    Text("Business Information").bold().font(.system(size: 33)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).offset(x: 5).padding()
                    ScrollView {
                        ForEach(self.subViewDict.keys.sorted(), id:\.self) { category in
                            VStack {
                                
                                NavigationLink(destination: subViewDict[category]) {
                                    HStack {
                                        Text(category).foregroundColor(colorScheme == .dark ? Color.white : Color.black).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                        Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
                                    }
                                }
                                
                                HorizontalLine(color: .gray, height: 0.5)
                                
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BusinessInfoSubView: View {
    var body: some View {
        Text("Business Info")
    }
}

struct PullToRefresh: View {
    
    var coordinateSpaceName: String
    var onRefresh: () -> Void
    
    @State var needRefresh: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            if (geo.frame(in: .named(coordinateSpaceName)).midY > 50) {
                Spacer()
                    .onAppear {
                        let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                        impactMed.impactOccurred()
                        needRefresh = true
                    }
            } else if (geo.frame(in: .named(coordinateSpaceName)).maxY < 10) {
                Spacer()
                    .onAppear {
                        if needRefresh {
                            needRefresh = false
                            onRefresh()
                        }
                    }
            }
            HStack {
                Spacer()
                VStack {
                    if needRefresh {
                        ProgressView()
                    }
                    Text("Pull to refresh").padding(.top)
                }
                Spacer()
            }
        }.padding(.top, -50)
    }
}

struct HorizontalLineShape: Shape {

    func path(in rect: CGRect) -> Path {

        let fill = CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height)
        var path = Path()
        path.addRoundedRect(in: fill, cornerSize: CGSize(width: 2, height: 2))

        return path
    }
}

struct HorizontalLine: View {
    private var color: Color? = nil
    private var height: CGFloat = 1.0

    init(color: Color, height: CGFloat = 1.0) {
        self.color = color
        self.height = height
    }

    var body: some View {
        HorizontalLineShape().fill(self.color ?? .black).frame(minWidth: 0, maxWidth: .infinity, minHeight: height, maxHeight: height)
    }
}
