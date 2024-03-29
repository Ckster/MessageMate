//
//  BusinessInformationView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth


let GENERAL_INFORMATION = "General Information"
let PERSONAL = "Personal"
let FAQS = "FAQs"
let LINKS = "Links"
let PRODUCTS_AND_SERVICES = "Products and Services"
let OTHER = "Other"


struct BusinessInformationView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    let db = Firestore.firestore()

    let subViewDict: Dictionary<String, AnyView> = [
        GENERAL_INFORMATION: AnyView(GeneralInfoSubView()),
        PERSONAL: AnyView(PersonalInfoSubView()),
        FAQS: AnyView(DynamicDictSubView(
            urlValueDict: [:], keyText: "Frequently asked question:",
            valueText: "Answer:",
            keyHeader: "FAQ",
            valueHeader: "Answer",
            promptText: "Or add all FAQs manually",
            websiteLinkPromptText: "Add a link to any of your website pages that answer FAQs and let the fields automatically generate. Feel free to add more manually.",
            websiteSection: "faqs_link",
            header: "Frequently Asked Questions",
            completeBeforeText: "Please fill out all FAQs before adding more",
            firebaseItemsField: Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.FAQS,
            disableAutoCorrect: false,
            disableAutoCapitalization: false)
        ),
        LINKS: AnyView(DynamicDictSubView(
            urlValueDict: [:],
            keyText: "Link type (Main website, scheduling, etc):",
            valueText: "URL (ex. awakenpermanentcosmetics.com):",
            keyHeader: "Link Type",
            valueHeader: "URL",
            promptText: "Please add any links that you commonly send to customers (i.e. scheduling link, website homepage, etc)",
            websiteLinkPromptText: nil,
            websiteSection: nil,
            header: "Links",
            completeBeforeText: "Please fill out all links before adding more",
            firebaseItemsField: Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS,
            disableAutoCorrect: true,
            disableAutoCapitalization: true)
        ),
        PRODUCTS_AND_SERVICES: AnyView(DynamicDictSubView(
            urlValueDict: [:],
            keyText: "Product or Service:",
            valueText: "Pricing Info:",
            keyHeader: "Product / Service",
            valueHeader: "Pricing Info",
            promptText: "Or add all of your products and services manually",
            websiteLinkPromptText: "Add a link to any of your website pages that list products or services and their descriptions, and let the fields automatically generate. Feel free to add more manually.",
            websiteSection: "products_services_link",
            header: "Products & Services",
            completeBeforeText: "Please fill out all products / services before adding more",
            firebaseItemsField: Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.PRODUCTS_SERVICES,
            disableAutoCorrect: false,
            disableAutoCapitalization: false)
        ),
        OTHER: AnyView(DynamicListSubView(
            listHeaderText: "Description:",
            inputText: "Specifics",
            promptText: "This section is for anything additional you would like to add. Anyting can be added; like instructions for the model \"Only mention free consultations if the customer is uncertain about buying a service\", to your opions \"My favorite procedure is lip blush\".",
            header: "Other instructions",
            completeBeforeText: "Please fill out all specifics before adding more",
            firebaseItemsField: Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SPECIFICS,
            disableAutoCorrect: false,
            disableAutoCapitalization: false)
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            
            if self.session.loadingPageInformation {
                LottieView(name: "Loading-2")
            }
            
            else {
                if self.session.selectedPage == nil {
                    
                    VStack(alignment: .center) {
                        Image("undraw_account_re_o7id").resizable().frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.30).offset(y: 0).padding()
                        
                        Text("Please connect a business page to your Facebook account so you can add information about it here").bold().font(Font.custom(REGULAR_FONT, size: 30)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.30, alignment: .leading).multilineTextAlignment(.center).lineSpacing(10)
                    }.offset(y: 50)
                }
                
                else {
                    NavigationView {
                        VStack(alignment: .center) {
                            Text("Business Information").font(Font.custom(BOLD_FONT, size: 30)).padding()
                            ForEach([GENERAL_INFORMATION, PERSONAL, FAQS, LINKS, PRODUCTS_AND_SERVICES, OTHER], id:\.self) { category in
                           
                                NavigationLink(destination: subViewDict[category].navigationBarHidden(category == GENERAL_INFORMATION || category == PERSONAL)) {
                                    Text(category)
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
                                .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.1)
                                .padding(.bottom)
                            }
                        }.frame(width: geometry.size.width)
                    }.navigationViewStyle(.stack)
                }
            }
        }
    }
}


let SENDER_CHARACTERTIC_EXAMPLE = "Example: Kind, concise, says \"girl\" often, uses ❤️, etc."
struct PersonalInfoSubView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State var senderName: String = ""
    @State var senderCharacteristics: String = ""
    @State var loading: Bool = true
    @FocusState var isFieldFocused: Bool
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        
        if self.loading {
            LottieView(name: "Loading-2").onAppear {
                self.getInfo()
            }
        }
        
        else {
            GeometryReader { geometry in
                VStack(alignment: .center) {
                    HStack {
                        Spacer()
                        Text("Personal").foregroundColor(textColor).font(Font.custom(BOLD_FONT, size: 25)).foregroundColor(textColor).frame(width: geometry.size.width * 0.65, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                            self.isFieldFocused = false
                        }
                        Button(action: {
                            self.updateInfo()
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Done").frame(width: geometry.size.width * 0.2).font(.system(size: 25))
                        }
                        Spacer()
                    }.padding(.top)
                    
                    ScrollView {
                        Text("Sender Name").font(Font.custom(BOLD_FONT, size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.15, alignment: .leading).contentShape(Rectangle()).onTapGesture {
                            self.isFieldFocused = false
                        }
                        GenericDynamicHeightTextBox(text: $senderName).frame(width: geometry.size.width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                        
                        Text("Sender Characteristics").font(Font.custom(BOLD_FONT, size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.15, alignment: .leading)                   .contentShape(Rectangle()).onTapGesture {
                            self.isFieldFocused = false
                        }
                        GenericDynamicHeightTextBox(text: $senderCharacteristics).frame(width: geometry.size.width * 0.85)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary).opacity(1))
                            .focused($isFieldFocused)
                        
                    }.frame(width: geometry.size.width)
                }
            }
        }
    }
    
    func getInfo() {
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            if error == nil {
                let data = doc?.data()
                if data != nil {
                    self.senderName = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME] as? String ?? ""
                    self.senderCharacteristics = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS] as? String ?? SENDER_CHARACTERTIC_EXAMPLE
                    self.loading = false
                }
            }
        }
    }
    
    func updateInfo() {
        var newData = [
            Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME: self.senderName,
        ]
        
        if self.senderCharacteristics != SENDER_CHARACTERTIC_EXAMPLE {
            newData[Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS] = self.senderCharacteristics
        }
    
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            newData
        )
    }
}

// TODO: Test for valid URL structure
struct singleInputLinkPopup: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var websiteURL: String
    @Binding var showingPopup: Bool
    @Binding var crawlingWebpage: Bool
    @FocusState var isPopupFocused: Bool
    let height: CGFloat
    let width: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                self.isPopupFocused = false
            }
            ZStack {
                let textColor: Color = self.colorScheme == .dark ? .black : .white
                RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color("Purple")).frame(width: width * 0.90, height: height * 0.5)
                VStack {
                    Text("Webpage URL:").font(Font.custom(REGULAR_FONT, size: 20)).foregroundColor(textColor).frame(width: width * 0.85, height: height * 0.10, alignment: .leading)
                    GenericDynamicHeightTextBox(text: self.$websiteURL).frame(width: width * 0.85)
                        .padding(.bottom).focused($isPopupFocused).autocorrectionDisabled(true).onChange(of: websiteURL) { _ in
                            if !websiteURL.filter({ $0.isNewline }).isEmpty {
                                self.isPopupFocused = false
                            }
                        }
                    
                    HStack {
                        Button(action: {
                            self.showingPopup = false
                            self.websiteURL = ""
                            self.isPopupFocused = false
                        }) {
                            Text("Cancel")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(Font.custom(REGULAR_FONT, size: 15))
                                .foregroundColor(textColor)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(self.colorScheme == .dark ? .black : .white, lineWidth: 4)
                                )
                                .lineLimit(1)
                        }
                        .background(Color.red)
                        .cornerRadius(25)
                        .frame(width: width * 0.25)
                        
                        Button(action: {
                            self.showingPopup = false
                            self.isPopupFocused = false
                            self.crawlingWebpage = true
                        }) {
                            Text("Done")
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .font(Font.custom(REGULAR_FONT, size: 15))
                                .foregroundColor(textColor)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(self.colorScheme == .dark ? .black : .white, lineWidth: 4)
                                )
                                .lineLimit(1)
                        }
                        .background(Color("Purple"))
                        .cornerRadius(25)
                        .frame(width: width * 0.25)
                    }
                }
            }
            .offset(y: self.showingPopup ? -150 : 0)
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture {
                self.isPopupFocused = false
            }
        }
    }
}


struct GenericDynamicHeightTextBox: View {
    @Binding var text: String
    @State var textEditorHeight : CGFloat = 65
    
    var body: some View {
        ZStack {
            ZStack(alignment: .bottomLeading) {
                Text(text)
                    .font(.system(.body))
                    .foregroundColor(.clear)
                    .padding(14)
                    .background(GeometryReader {
                        Color.clear.preference(key: ViewHeightKey.self,
                                               value: $0.frame(in: .local).size.height)
                    })
                
                TextEditor(text: $text)
                    .font(.system(.body))
                    .padding(7)
                    .frame(height: textEditorHeight)
            }
        .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
        }
    }
}


struct websiteURLTextEditor: View {
    @State var websiteURL: String = ""
    @FocusState var isTextEditorFocused: Bool // TODO: Get this passed in from parent view
    @Binding var urlValueDict: [UUID: String]
    
    let height: CGFloat
    let width: CGFloat
    let id: UUID = UUID()
    
    var body: some View {
        VStack {
        
            Text("Webpage URL:")
                .frame(width: width * 0.85, height: height * 0.10, alignment: .leading)
                .font(Font.custom(REGULAR_FONT, size: 25))
            
            GenericDynamicHeightTextBox(text: self.$websiteURL)
                .frame(width: width * 0.85)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary)
                        .opacity(1.0)
                )
                .focused($isTextEditorFocused)
                .autocorrectionDisabled(true)
                .onChange(of: websiteURL) { _ in
                    if !websiteURL.filter({ $0.isNewline }).isEmpty {
                        self.isTextEditorFocused = false
                    }
                    self.urlValueDict[id] = websiteURL
                }
            
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    self.isTextEditorFocused = false
                }
                
        }
        .onAppear(perform: {
            self.websiteURL = self.urlValueDict[self.id]!
        })
    }
}

// TODO: Add a binding for a dictionary of values so the website URL from each view can be kept track of
struct multipleInputLinkPopup: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var urlTextEditors: [websiteURLTextEditor]
    @Binding var urlValueDict: [UUID: String]
    @Binding var showingPopup: Bool
    @Binding var crawlingWebpage: Bool
    @State var viewToNavigateTo: UUID? = nil
    let height: CGFloat
    let width: CGFloat
    
    var body: some View {
        ZStack {
            let textColor: Color = self.colorScheme == .dark ? .black : .white
            RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color("Purple")).frame(width: width * 0.90, height: height * 0.95)
            VStack {
                Text("Webpage URLs:")
                    .font(Font.custom(REGULAR_FONT, size: 20))
                    .foregroundColor(textColor)
                    .frame(width: width * 0.85, height: height * 0.10, alignment: .leading)
                
                ScrollView {
                    ScrollViewReader {
                        value in
                        VStack {
                            ForEach(self.urlTextEditors, id: \.self.id) {
                                textEditor in
                                
                                let navView = HStack {
                                    Text(self.urlValueDict[textEditor.id]!)
                                        .frame(width: width * 0.8, alignment: .leading)
                                        .lineLimit(5)
                                        .font(Font.custom(REGULAR_FONT, size: 20))
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(textColor)
                                    Image(systemName: "chevron.right")
                                        .imageScale(.large)
                                        .offset(x: -10)
                                        .foregroundColor(textColor)
                                }
                                
                                NavigationLink(destination: textEditor, tag: textEditor.id, selection: self.$viewToNavigateTo) {
                                    navView
                                }.id(textEditor.id)
                                
                                HorizontalLine(color: textColor, height: 2.5)
                                
                            }
                            .padding(.bottom)
                            
                            Image(systemName: "plus.circle")
                                .font(.system(size: 45))
                                .foregroundColor(textColor)
                                .onTapGesture {
                                    // Only let user add a new field if all existing have been filled out
                                    for url in self.urlValueDict.values {
                                        if url == "" {
                                            return
                                        }
                                    }
                                    
                                    self.addTextEditor()
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        value.scrollTo(1)
                                    }
                                }
                                .frame(width: width, alignment: .center).id(1)
                                .onChange(of: showingPopup, perform: { showingPopup in
                                    if showingPopup && self.urlTextEditors.count == 0 {
                                        self.addTextEditor()
                                    }
                                })
                            Spacer()
                        }
                    }
                }
                .frame(width: width * 0.85, height: height * 0.65)
            
                HStack {
                    Button(action: {
                        self.showingPopup = false
                    }) {
                        Text("Cancel")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 15))
                            .foregroundColor(textColor)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .black : .white, lineWidth: 4)
                            )
                            .lineLimit(1)
                    }
                    .background(Color.red)
                    .cornerRadius(25)
                    .frame(width: width * 0.25)
                    
                    Button(action: {
                        self.showingPopup = false
                        self.crawlingWebpage = true
                    }) {
                        Text("Done")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 15))
                            .foregroundColor(textColor)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(self.colorScheme == .dark ? .black : .white, lineWidth: 4)
                            )
                            .lineLimit(1)
                    }
                    .background(Color("Purple"))
                    .cornerRadius(25)
                    .frame(width: width * 0.25)
                }
                .frame(height: height * 0.2)
            }
        }
    }
    
    func addTextEditor() {
        let newTextEditor = websiteURLTextEditor(urlValueDict: self.$urlValueDict, height: height, width: width)
        self.urlValueDict[newTextEditor.id] = ""
        self.viewToNavigateTo = newTextEditor.id
        self.urlTextEditors.append(newTextEditor)
    }
}



extension View {

    public func popup<PopupContent: View>(
        isPresented: Binding<Bool>,
        view: @escaping () -> PopupContent) -> some View {
        self.modifier(
            Popup(
                isPresented: isPresented,
                view: view)
        )
    }
}


public struct Popup<PopupContent>: ViewModifier where PopupContent: View {
    
    init(isPresented: Binding<Bool>,
         view: @escaping () -> PopupContent) {
        self._isPresented = isPresented
        self.view = view
    }
    
    /// Controls if the sheet should be presented or not
    @Binding var isPresented: Bool
    
    /// The content to present
    var view: () -> PopupContent
    
    public func body(content: Content) -> some View {
        ZStack {
            content
              .frameGetter($presenterContentRect)
        }
        .overlay(sheet())
    }

    func sheet() -> some View {
        ZStack {
            self.view()
              .frameGetter($sheetContentRect)
              .frame(width: screenWidth)
              .offset(x: 0, y: currentOffset)
              .animation(Animation.easeOut(duration: 0.3), value: currentOffset)
        }
    }

    private func dismiss() {
        isPresented = false
    }
    
    @State private var presenterContentRect: CGRect = .zero

    /// The rect of popup content
    @State private var sheetContentRect: CGRect = .zero

    /// The offset when the popup is displayed
    private var displayedOffset: CGFloat {
        -presenterContentRect.midY + screenHeight/2
    }

    /// The offset when the popup is hidden
    private var hiddenOffset: CGFloat {
        if presenterContentRect.isEmpty {
            return 1000
        }
        return screenHeight - presenterContentRect.midY + sheetContentRect.height/2 + 5
    }

    /// The current offset, based on the "presented" property
    private var currentOffset: CGFloat {
        return isPresented ? displayedOffset : hiddenOffset
    }
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.size.width
    }

    private var screenHeight: CGFloat {
        UIScreen.main.bounds.size.height
    }
    
}
    
    
    
extension View {
    func frameGetter(_ frame: Binding<CGRect>) -> some View {
        modifier(FrameGetter(frame: frame))
    }
}
  
struct FrameGetter: ViewModifier {
  
    @Binding var frame: CGRect
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy -> AnyView in
                    let rect = proxy.frame(in: .global)
                    // This avoids an infinite layout loop
                    if rect.integral != self.frame.integral {
                        DispatchQueue.main.async {
                            self.frame = rect
                        }
                    }
                return AnyView(EmptyView())
            })
    }
}
    

struct GeneralInfoSubView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState var isFieldFocused: Bool
    @State var businessName: String = ""
    @State var address: String = ""
    @State var industry: String = ""
    @State var hours: String = ""
    @State var loading: Bool = true
    @State var showingPopup: Bool = false
    @State var workingWebsiteURL: String = ""
    @State var crawlingWebpage: Bool = false
    
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        
        if self.loading {
            LottieView(name: "Loading-2").onAppear {
                self.getInfo()
            }
        }
        
        else {
            // TODO: Add hours field
            GeometryReader { geometry in
                VStack(alignment: .center) {
                    
                    HStack {
                        Spacer()
                        Text("General Information").foregroundColor(textColor).font(Font.custom(BOLD_FONT, size: 25)).foregroundColor(textColor).frame(width: geometry.size.width * 0.65, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                            self.isFieldFocused = false
                        }
                        Button(action: {
                            self.updateInfo()
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Done").frame(width: geometry.size.width * 0.2).font(.system(size: 25))
                        }
                        Spacer()
                    }.padding(.top)
                    
                    Text("Add a link(s) to your websites's home page and let the fields automatically generate as long as the information is present on your homepage").font(Font.custom(REGULAR_FONT, size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.15, alignment: .leading).padding(.top).padding(.leading).contentShape(Rectangle()).onTapGesture {
                        self.isFieldFocused = false
                    }
                    Button(action: {self.showingPopup = true}) {
                        Text("Link a webpage")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .font(Font.custom(REGULAR_FONT, size: 25))
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
                    .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.075)
                    .padding(.bottom).padding(.top).padding(.leading)
                    .allowsHitTesting(!showingPopup)
                    
                    if self.crawlingWebpage {
                        VStack {
                            Text("Retrieving information from webpage ...").font(Font.custom(BOLD_FONT, size: 20))
                            LottieView(name: "Loading-2").frame(width: 300, height: 300)
                        }.onAppear(perform: {
                            getCrawlerResults {
                                self.crawlingWebpage = false
                            }
                        })
                        .padding(.top)
                    }
                    
                    else {
                        Text("Or fill in fields manually").font(Font.custom(REGULAR_FONT, size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.10, alignment: .leading).padding(.top).padding(.leading).contentShape(Rectangle()).onTapGesture {
                            self.isFieldFocused = false
                        }
                        
                        ScrollView {
                            Text("Business Name").bold().font(.system(size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.10, alignment: .leading).contentShape(Rectangle()).onTapGesture {
                                self.isFieldFocused = false
                            }
                            GenericDynamicHeightTextBox(text: $businessName).frame(width: geometry.size.width * 0.85)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(1))
                                .focused($isFieldFocused)
                                .allowsHitTesting(!showingPopup)
                            
                            Text("Industry").bold().font(.system(size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading).contentShape(Rectangle()).onTapGesture {
                                self.isFieldFocused = false
                            }
                            GenericDynamicHeightTextBox(text: $industry).frame(width: geometry.size.width * 0.85)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(1))
                                .focused($isFieldFocused)
                                .allowsHitTesting(!showingPopup)
                            
                            Text("Hours").bold().font(.system(size: 20)).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.10, alignment: .leading).contentShape(Rectangle()).onTapGesture {
                                self.isFieldFocused = false
                            }
                            GenericDynamicHeightTextBox(text: $hours).frame(width: geometry.size.width * 0.85)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(1))
                                .focused($isFieldFocused)
                                .allowsHitTesting(!showingPopup)
                        }
                    }
                }
                .opacity(self.showingPopup ? 0.15 : 1.0)
                .popup(isPresented: $showingPopup) {
                    singleInputLinkPopup(websiteURL: $workingWebsiteURL, showingPopup: $showingPopup, crawlingWebpage: $crawlingWebpage, height: geometry.size.height, width: geometry.size.width)
                }
            }
        }
    }
    
    func getInfo() {
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            if error == nil {
                let data = doc?.data()
                if data != nil {
                    self.address = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_ADDRESS] as? String ?? ""
                    self.businessName = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME] as? String ?? ""
                    self.industry = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY] as? String ?? ""
                    self.hours = data![Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.HOURS] as? String ?? ""
                    self.loading = false
                }
            }
        }
        
    }
    
    func updateInfo() {
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_ADDRESS: self.address,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME: self.businessName,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY: self.industry,
                Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.HOURS: self.hours
            ]
        )
    }
    
    func getCrawlerResults(completion: @escaping () -> Void) {
        let crawlerResponse = webcrawlRequest(section: "homepage_link", urls: [self.workingWebsiteURL]) {
            response in
            print(response)
            self.address = response["business_address"] as? String ?? ""
            self.businessName = response["business_name"] as? String ?? ""
            self.industry = response["industry"] as? String ?? ""
            self.hours = response["hours"] as? String ?? ""
            self.updateInfo()
            completion()
        }
    }
    
}


struct InputBoxView: View {
    
    var heading: String = ""
    var placeholderText: String?
    @Binding var input: String
    
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var autoCorrect: Bool = true
            
    var body: some View {
        VStack {
            Text(heading).frame(width: width, alignment: .leading).font(.system(size: 15)).foregroundColor(.gray)
            NeumorphicStyleTextField(textField: TextField("", text: $input), sfName: nil, imageName: nil, textBinding: $input, placeholderText: placeholderText ?? heading, autoCorrect: autoCorrect, fontSize: fontSize)

        }.frame(width: width)
    }
}

struct NeumorphicStyleTextField: View {
    @Environment(\.colorScheme) var colorScheme
    var textField: TextField<Text>
    var sfName: String?
    var imageName: String?
    @Binding var textBinding: String
    let placeholderText: String
    var autoCorrect: Bool
    let fontSize: CGFloat
    @State var isTapped: Bool = false
    @FocusState var isFieldFocused: Bool
    
    init(textField: TextField<Text>, sfName: String?, imageName: String?, textBinding: Binding<String>, placeholderText: String, autoCorrect: Bool = true, fontSize: CGFloat) {
        self.textField = textField
        self.sfName = sfName
        self.imageName = imageName
        _textBinding = textBinding
        self.placeholderText = placeholderText
        self.autoCorrect = autoCorrect
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack {
            
            if sfName != nil {
                Image(systemName: sfName!)
                    .foregroundColor(.darkShadow)
            }
            else {
                if imageName != nil {
                    Image(imageName!)
                        .foregroundColor(.white)
                }
            }
            
            textField.placeholder(when: textBinding.isEmpty) {Text(self.placeholderText).foregroundColor(self.colorScheme == .dark ? .white : .black)}.autocorrectionDisabled(!autoCorrect)
            
            }
            .padding()
            .foregroundColor(.white)
            .background(self.colorScheme == .dark ? Color.textBoxGgray : .gray)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(self.isFieldFocused ? self.colorScheme == .dark ? .white : .black : .clear, lineWidth: 1)
            )
            .padding(.trailing)
            .font(.system(size: fontSize))
            .focused($isFieldFocused)
            
    }
}

struct NeumorphicStyleButton: View {
    var sfName: String?
    var imageName: String?
    let placeholderText: String
    let geometry: GeometryProxy
    
    init(sfName: String?, imageName: String?, placeholderText: String, geometry: GeometryProxy) {
        self.sfName = sfName
        self.imageName = imageName
        self.placeholderText = placeholderText
        self.geometry = geometry
    }
    
    var body: some View {
        HStack {
            if sfName != nil {
                Image(systemName: sfName!)
                    .foregroundColor(.darkShadow)
            }
            else {
                if imageName != nil {
                    Image(imageName!)
                        .foregroundColor(.white)
                }
            }
            Text(self.placeholderText).foregroundColor(.gray)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.black)
            .cornerRadius(10)
            .shadow(color: .gray, radius: 3, x: 2, y: 2)
            .shadow(color: .gray, radius: 3, x: -2, y: -2)
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

func webcrawlRequest(section: String, urls: [String], completion: @escaping ([String: Any]) -> Void) {
    let urlString = "https://us-central1-messagemate-2d9af.cloudfunctions.net/autofill_info_http"
    let currentUser = Auth.auth().currentUser
    
    currentUser?.getIDTokenForcingRefresh(true) { idToken, error in
        if let error = error {
            // TODO: Tell user there was an issue and to try again
            print(error, "ERROR")
            return
        }
        
        let header: [String: String] = [
            "authorization": idToken!,
            "section": section
        ]
        
        let body = [
            "urls": urls
        ]
        
        let bodyData = try? JSONSerialization.data(withJSONObject: body)
        
        if bodyData != nil {
            postRequestJSON(urlString: urlString, header: header, data: bodyData!) {
                data in
                if data != nil {
                    completion(data!["crawlResults"] as? [String: Any] ?? ["error": ""]) // TODO: Process an actual error message from response
                }
            }
        }
        else {
            print("Body data nil")
            completion(["Body data nil": nil])
        }
    }
}


func keyToType(input: String) -> String {
    let sep = input.split(separator: "_")
    var newStr = ""
    for w in sep {
        newStr = newStr + w.capitalized
        if w != sep.last {
            newStr = newStr + " "
        }
    }
    return newStr
}


func typeToKey(input: String) -> String {
    let sep = input.split(separator: " ")
    var newStr = ""
    for w in sep {
        newStr = newStr + w.lowercased()
        if w != sep.last {
            newStr = newStr + "_"
        }
    }
    return newStr
}



extension Color {
    static let lightShadow = Color(red: 255 / 255, green: 255 / 255, blue: 255 / 255)
    static let darkShadow = Color(red: 163 / 255, green: 177 / 255, blue: 198 / 255)
    static let background = Color(red: 224 / 255, green: 229 / 255, blue: 236 / 255)
    static let neumorphictextColor = Color(red: 132 / 255, green: 132 / 255, blue: 132 / 255)
    static let textBoxGgray = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
