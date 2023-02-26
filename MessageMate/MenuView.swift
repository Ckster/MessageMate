//
//  MenuView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/25/23.
//

import SwiftUI


struct MenuView: View {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var showingSignOutAlert: Bool = false

    var body: some View {
        let signOutAlert =
            Alert(title: Text("Sign Out"), message: Text("Are you sure you would like to sign out?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Sign Out"), action: {
                self.session.signOut()
            }))

        NavigationView {
            ZStack {
                Color(self.colorScheme == .dark ? .black : .white)
                HStack {
                    VStack(alignment: .leading) {

                        AsyncImage(url: URL(string: self.session.selectedPage?.photoURL ?? "")) { image in image.resizable() } placeholder: { LottieView(name: "97952-loading-animation-blue") } .frame(width: width * 0.65, height: height * 0.1) .clipShape(Circle())
                        
                        if self.session.selectedPage?.name != nil {
                            Text(self.session.selectedPage!.name).bold().font(.system(size: 18))
                                .padding(.leading)
                        }
                        
                        if self.session.user.user?.email != nil {
                            Text(verbatim: session.user.user!.email!).foregroundColor(.gray).font(.system(size: 15))
                                .padding(.leading)
                        }
                        
                        Divider()
                        
                        NavigationLink(destination: SelectPageView(width: width * 0.65, height: height).environmentObject(self.session)) {
                            HStack {
                                Image(systemName: "list.bullet").font(.system(size: 30)).padding(.trailing)
                                Text("Select Page").font(.system(size: 25))
                            }.padding(.leading).padding(.bottom)
                        }.buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Image(systemName: "info.square").font(.system(size: 30)).padding(.trailing)
                            Text("About").font(.system(size: 25))
                        }.padding(.leading).padding(.bottom)

                        HStack {
                            Image(systemName: "arrow.left.to.line.circle").font(.system(size: 30)).padding(.trailing)
                            Text("Sign Out").font(.system(size: 25)).onTapGesture {
                                self.showingSignOutAlert = true
                            }.alert(isPresented: $showingSignOutAlert) {
                                signOutAlert
                            }
                        }.padding(.leading)

                        Text("© MessageMate 2023").font(.system(size: 20)).padding(.leading).frame(width: width * 0.65, height: height * 0.58, alignment: .bottom)

                    }.frame(height: height)

                    Divider()
                }
            }.frame(width: width * 0.65, height: height)
        }
    }
}
