//
//  OnboardingView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore


enum currentView {
    case intro
    case info
    case complete
}


let screenSize = UIScreen.main.bounds
let screenWidth = screenSize.width
let screenHeight = screenSize.height

let senderNameExample = "Ex. Jane Doe"
let senderCharacteristicsExample = "Ex. Clear, concise, down to Earth, sometimes calls people girl"
let businessNameExample = "Ex. Noon Moon Coffee"
let industryExample = "Ex. Coffee shop and bakery"


struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore

    @State var activeView: currentView = .intro
    @State var viewState = CGSize.zero
    
    @State var senderName: String = senderNameExample
    @State var senderCharacteristics: String = senderCharacteristicsExample
    @State var businessName: String = businessNameExample
    @State var industry: String = industryExample

    var db = Firestore.firestore()
    let contentView: ContentView
    
    var body: some View {
        GeometryReader {
            geometry in
            VStack {
                ZStack {
                    IntroView(width: geometry.size.width, height: geometry.size.height)
                        .offset(x: self.activeView == .intro ? 0 : self.activeView == .info ? -screenWidth : -2 * screenWidth)
                        .offset(x: self.activeView != .complete ? self.viewState.width : 0)
                        .animation(.easeInOut)
                    
                    InfoView(senderName: self.$senderName, senderCharacteristics: self.$senderCharacteristics, businessName: self.$businessName, industry: self.$industry, width: geometry.size.width, height: geometry.size.height, contentView: contentView)
                        .environmentObject(self.session)
                        .offset(x: self.activeView == .info ? 0 : self.activeView == .intro ? screenWidth : -screenWidth)
                        .offset(x: self.viewState.width)
                        .animation(.easeInOut)
                    
                    CompleteView(width: geometry.size.width, height: geometry.size.height, senderName: self.$senderName, senderCharacteristics: self.$senderCharacteristics, businessName: self.$businessName, industry: self.$industry)
                        .offset(x: self.activeView == .complete ? 0 : self.activeView == .intro ? screenWidth * 2 : screenWidth)
                        .offset(x: self.activeView != .intro ? self.viewState.width : 0)
                        .animation(.easeInOut)
            
                }.frame(width: geometry.size.width, height: geometry.size.height * 0.975)
                
                ZStack {
                    Color.clear
                    HStack() {
                        Circle()
                            .fill(self.activeView == .intro ? Color("Purple") : Color.gray)
                            .frame(width: geometry.size.width * 0.25)
                        Circle()
                            .fill(self.activeView == .info ? Color("Purple") : Color.gray)
                            .frame(width: geometry.size.width * 0.25)
                        Circle()
                            .fill(self.activeView == .complete ? Color("Purple") : Color.gray)
                            .frame(width: geometry.size.width * 0.25)
                    }.frame(width: geometry.size.width * 0.75, height: geometry.size.height * 0.025).offset(y: -40)
                }
                .ignoresSafeArea(.keyboard)
            }
            
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        print(value)
                switch self.activeView {
                case .intro:
                    guard value.translation.width < 1 else {return}
                    self.viewState = value.translation
                case .info:
                    self.viewState = value.translation
                case .complete:
                    guard value.translation.width > 1 else {return}
                    self.viewState = value.translation
                }
                    }
                
                    .onEnded {
                        value in
                        print(value)
                        switch self.activeView {
                        case .intro:
                            if value.predictedEndTranslation.width < -screenWidth / 2 {
                                self.activeView = .info
                            }
                            self.viewState = .zero
                            
                        case .complete:
                            if value.predictedEndTranslation.width > screenWidth / 2 {
                                self.activeView = .info
                            }
                            self.viewState = .zero
                        case .info:
                            if value.predictedEndTranslation.width < -screenWidth / 2 {
                                self.activeView = .complete
                            }
                            
                            if value.predictedEndTranslation.width > screenWidth / 2 {
                                self.activeView = .intro
                            }
                            self.viewState = .zero
                        }
                    }
            )
        }
    }
}


struct IntroView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(alignment: .center) {
            Image("undraw_setup_wizard_re_nday").resizable().frame(width: width * 0.75, height: height * 0.35).offset(y: 0).padding()
            
            Text("Let's Get Started").bold().frame(width: width * 0.75, height: height * 0.07).font(Font.custom(EXTRA_BOLD_FONT, size: 37)).lineLimit(1)
            
            Text("After adding some basic information about your business you'll be able to generate personalized replies at the click of a button").frame(width: width * 0.75, height: height * 0.25).lineSpacing(7).font(Font.custom(REGULAR_FONT, size: 20)).multilineTextAlignment(.center)
            
                //.offset(y: -50)
            //Spacer()
            //Image(systemName: "arrow.forward").frame(height: height * 0.15).font(.system(size: 35))
        }.offset(y: -100)
    }
}


// TODO: Fix the lag on this screen
struct InfoView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.managedObjectContext) var moc
    @State var initializing: Bool = true
    @Binding var senderName: String
    @Binding var senderCharacteristics: String
    @Binding var businessName: String
    @Binding var industry: String
    @FocusState var isFieldFocused: Bool
    let width: CGFloat
    let height: CGFloat
    let contentView: ContentView
    
    var body: some View {

        if self.session.facebookUserToken == nil {
            FacebookAuthenticateView(width: width, height: height).environmentObject(session)
        }
        
        else {
            if self.initializing {
                VStack {
                    LottieView(name: "Loading-2")
                    Text("Initializing page(s) ...").offset(y: -150).font(Font.custom(BOLD_FONT, size: 20))
                }
                .onAppear {
                    Task {
                        self.session.initializingPageOnOnboarding = true
                        print("Initializing B")
                        self.contentView.initializePageInfo()
                    }
                }
                .onChange(of: self.session.initializingPageOnOnboarding, perform: {
                    initializing in
                    if initializing != nil && !initializing! {
                        self.initializing = false
                    }
                })
            }
            
            else {
                if true
                //    self.session.activePages.count == 0
                {
                    
                    NoBusinessAccountsLinkedView(width: width, height: height).environmentObject(self.session)
                        .onChange(of: self.session.facebookUserToken, perform: {
                            newToken in
                            if newToken != nil {
                                self.initializing = true
                            }
                        }
                    )
                }
                
                else {
                    VStack {
                        Text("Basic Information").bold().font(Font.custom(EXTRA_BOLD_FONT, size: 37)).lineLimit(1).frame(width: width, height: height * 0.10, alignment: .center)
                        
                        Text("Business Name").bold().font(Font.custom(BOLD_FONT, size: 20)).frame(width: width * 0.85, height: height * 0.08, alignment: .leading)
                        GenericDynamicHeightTextBox(text: $businessName)
                            .frame(width: width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                            .onTapGesture {
                                if self.businessName == businessNameExample {
                                    self.businessName = ""
                                }
                            }
                            
                        Text("Industry").bold().font(Font.custom(BOLD_FONT, size: 20)).frame(width: width * 0.85, height: height * 0.08, alignment: .leading)
                        GenericDynamicHeightTextBox(text: $industry)
                            .frame(width: width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                            .onTapGesture {
                                if self.industry == industryExample {
                                    self.industry = ""
                                }
                            }
                        
                        Text("Sender Name").bold().font(Font.custom(BOLD_FONT, size: 20)).frame(width: width * 0.85, height: height * 0.08, alignment: .leading)
                        GenericDynamicHeightTextBox(text: $senderName)
                            .frame(width: width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                            .onTapGesture {
                                if self.senderName == senderNameExample {
                                    self.senderName = ""
                                }
                            }
                             
                        Text("Sender Characteristics").bold().font(Font.custom(BOLD_FONT, size: 20)).frame(width: width * 0.85, height: height * 0.08, alignment: .leading)
                        GenericDynamicHeightTextBox(text: $senderCharacteristics)
                            .frame(width: width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                            .onTapGesture {
                                if self.senderCharacteristics == senderCharacteristicsExample {
                                    self.senderCharacteristics = ""
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.isFieldFocused = false
                        }
                        .offset(y: -50)
                    }
            }
        }
    }
}



struct CompleteView: View {
    let width: CGFloat
    let height: CGFloat
    let db = Firestore.firestore()
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var senderName: String
    @Binding var senderCharacteristics: String
    @Binding var businessName: String
    @Binding var industry: String
    @State var addInfoMessage: String = ""
    
    @ObservedObject var tabSelectionState = TabSelectionState.shared
    
    var body: some View {
        ZStack {
            VStack(alignment: .center) {
                Image("undraw_add_information_j2wg").resizable().frame(width: width * 0.9, height: height * 0.30).offset(y: 0).padding()
                
                Text("MessageMate gets better at generating responses the more information you tell it about your business. You can go to the business information screen at any time to add business info, FAQs, products, services, and website links.").bold().font(Font.custom(REGULAR_FONT, size: 20)).frame(width: width * 0.85, height: height * 0.30, alignment: .leading).multilineTextAlignment(.center).lineSpacing(10)
                
                Button(action: {
                    let minInfo = self.checkForMinInfo()
                    
                    if minInfo {
                        
                        self.db.collection(Users.name).document(self.session.user.user!.uid).updateData([Users.fields.ONBOARDING_COMPLETED: true], completion: {
                            error in
                            if error == nil {
                                self.updateInfo() {
                                    DispatchQueue.main.async {
                                        self.tabSelectionState.selectedTab = 1 // Inbox tab
                                    }
                                    self.session.onboardingCompleted = true
                                }
                            }
                            else {
                                Text("Oof, there was an error")
                            }
                        })
                        
                    }
                    }) {
                        Text("Take me to fill out more info")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 18))
                            .foregroundColor(self.colorScheme == .dark ? .white : .black)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 2)
                            )
                            .lineLimit(1)
                    }
                    .background(Color("Purple"))
                    .cornerRadius(25)
                    .frame(width: width * 0.85, height: height * 0.075)
                
                
                Button(action: {
                    let minInfo = self.checkForMinInfo()
                    
                    if minInfo {
                        
                        self.db.collection(Users.name).document(self.session.user.user!.uid).updateData([Users.fields.ONBOARDING_COMPLETED: true], completion: {
                            error in
                            if error == nil {
                                self.updateInfo() {
                                    DispatchQueue.main.async {
                                        self.tabSelectionState.selectedTab = 2 // Inbox tab
                                    }
                                    self.session.onboardingCompleted = true
                                }
                            }
                            else {
                                Text("Oof, there was an error")
                            }
                        })
                        
                    }
                    }) {
                        Text("I'll add more later, take me to my inbox")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 18))
                            .foregroundColor(self.colorScheme == .dark ? .white : .black)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .white : .black, lineWidth: 2)
                            )
                            .lineLimit(1)
                    }
                    .background(Color("Purple"))
                    .cornerRadius(25)
                    .frame(width: width * 0.85, height: height * 0.075)
                
            }
            .offset(y: -50)
            
            if self.addInfoMessage != "" {
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(Color("Purple"))
                    .frame(width: width * 0.85, height: 150, alignment: .center)
                    .overlay(
                        Text(self.addInfoMessage).frame(width: width * 0.85, height: 150, alignment: .center)
                    ).padding(.leading)
            }
            
        }
    }
    
    func checkForMinInfo() -> Bool {
        var fillOut: [String] = []
        if self.senderName == "" || self.senderName == senderNameExample {
            fillOut.append("Sender Name")
        }
        if self.senderCharacteristics == "" || self.senderCharacteristics ==  senderCharacteristicsExample {
            fillOut.append("Sender Characteristics")
        }
        if self.businessName == "" || self.businessName == businessNameExample {
            fillOut.append("Business Name")
        }
        if self.industry == "" || self.industry == industryExample {
            fillOut.append("Industry")
        }
        
        if fillOut.count > 0 {
            var infoMessage: String = "Please fill out these fields before continuing: \n"
            for s in fillOut {
                infoMessage = infoMessage + "\(s)\n"
            }
            self.addInfoMessage = infoMessage
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.addInfoMessage = ""
            }
            return false
        }
        else {
            return true
        }
    }
    
    func updateInfo(completion: @escaping () -> Void) {
            self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").setData(
            [
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME: self.senderName,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS: self.senderCharacteristics,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME: self.businessName,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY: self.industry
            ], completion: {
                error in
                if error == nil {
                    completion()
                }
                else {
                    print("There was an error")
                    // TODO: tell user there was an error
                }
            }
            )
        }
}
