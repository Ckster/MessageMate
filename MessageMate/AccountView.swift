//
//  MenuView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/25/23.
//

import SwiftUI


struct AccountView: View {
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

            VStack(alignment: .center, spacing: 5) {
                
                AsyncImage(url: URL(string: self.session.selectedPage?.photoURL ?? "")) { image in image.resizable() } placeholder: { LottieView(name: "Loading-2") } .frame(width: 75, height: 75).overlay(
                    Circle()
                        .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 2)
                ).clipShape(Circle()).padding(.top)
                
                if self.session.selectedPage?.name != nil {
                    Text(self.session.selectedPage!.name!).bold().font(Font.custom(BOLD_FONT, size: 30))
                }
                //Use page.pageUser for info
                if self.session.user.user?.email != nil {
                    Text(verbatim: session.user.user!.email!).foregroundColor(.gray).font(Font.custom(REGULAR_FONT, size: 15))
                }
                
                Spacer()
            
                // Select Page link
                NavigationLink(destination: SelectPageView(width: width, height: height).environmentObject(self.session)) {
                    Text("Manage Pages")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .font(Font.custom(REGULAR_FONT, size: 30))
                        .foregroundColor(self.colorScheme == .dark ? .white: .black)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 4)
                        )
                        .lineLimit(1)
                    }
                .background(Color("Purple"))
                .cornerRadius(25)
                .frame(width: width * 0.85, height: height * 0.1)
                .padding(.bottom)
                
                // Sign out
                Button(action: {
                    self.showingSignOutAlert = true
                    }) {
                        Text("Sign Out")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 30))
                            .foregroundColor(self.colorScheme == .dark ? .white : .black)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 4)
                            )
                            .lineLimit(1)
                    }
                    .background(Color("Purple"))
                    .cornerRadius(25)
                    .frame(width: width * 0.85, height: height * 0.1)
                    .alert(isPresented: $showingSignOutAlert) {
                        signOutAlert
                    }
                    .padding(.bottom)
                
                // Delete account
                Button(action: {
                    }) {
                        Text("Delete Account")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 30))
                            .foregroundColor(self.colorScheme == .dark ? .white : .black)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 4)
                            )
                            .lineLimit(1)
                    }
                    .background(Color("Purple"))
                    .cornerRadius(25)
                    .frame(width: width * 0.85, height: height * 0.1)
                
                Text("© Interactify 2023").font(Font.custom(REGULAR_FONT, size: 20)).frame(width: width, height: height * 0.35, alignment: .bottom).offset(y: -20)

            }

        }
    }
}
