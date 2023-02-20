//
//  BusinessInformationView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore

//"Website: awakenpermanentcosmetics.com. Scheduling appointment link: https://koalendar.com/e/schedule-my-pmu"
// "All services include 2 appointments and a free completely optional 20-30 minute consultation. Lip blush: Initial Deposit is $150 then First session is $350 and the second session 6 weeks later is $100. Powder brows: booking deposit $150, first session $325 and the second session 6 weeks later $100. Lash line enhancement: booking deposit ($150), first session ($200), and a second session 6 weeks later ($50)"

struct BusinessInformationView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme

    let subViewDict: Dictionary<String, AnyView> = [
        "General": AnyView(GeneralInfoSubView()),
        "Business Info": AnyView(BusinessInfoSubView()),
        "Links": AnyView(DynamicDictSubView(
            keyText: "Link type (Main website, scheduling, etc):",
            valueText: "URL (ex. awakenpermanentcosmetics.com):",
            keyHeader: "Link Type",
            valueHeader: "URL",
            promptText: "Please add links to your businesse's web services:",
            header: "Links",
            completeBeforeText: "Please fill out all links before adding more",
            firebaseItemsField: Users.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS)
        ),
        "Products and Services": AnyView(DynamicDictSubView(
            keyText: "Product or Service:",
            valueText: "Pricing Info:",
            keyHeader: "Product / Service",
            valueHeader: "Pricing Info",
            promptText: "Please add the products and services that your business offers:",
            header: "Products & Services",
            completeBeforeText: "Please fill out all products / services before adding more",
            firebaseItemsField: Users.collections.BUSINESS_INFO.documents.FIELDS.fields.PRODUCTS_SERVICES)
        ),
        "FAQs": AnyView(DynamicDictSubView(
            keyText: "Frequently asked question:",
            valueText: "Answer:",
            keyHeader: "FAQ",
            valueHeader: "Answer",
            promptText: "Please add any frequently asked questions of your business",
            header: "Frequently Asked Questions",
            completeBeforeText: "Please fill out all FAQs before adding more",
            firebaseItemsField: Users.collections.BUSINESS_INFO.documents.FIELDS.fields.FAQS)
        ),
        "Specifics": AnyView(DynamicListSubView(listHeaderText: "Descriptions:", inputText: "Specifics", promptText: "Please add any specfic information about your business", header: "Business Specifics", completeBeforeText: "Please fill out all specifics before adding more", firebaseItemsField: Users.collections.BUSINESS_INFO.documents.FIELDS.fields.SPECIFICS))
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    Text("Business Information").bold().font(.system(size: 30)).offset(x: 0).padding(.leading).padding(.bottom)
                    ScrollView {
                        ForEach(self.subViewDict.keys.sorted(), id:\.self) { category in
                            VStack {
                                NavigationLink(destination: subViewDict[category]) {
                                    HStack {
                                        Text(category).foregroundColor(colorScheme == .dark ? Color.white : Color.black).font(.system(size: 23)).frame(width: geometry.size.width * 0.85, alignment: .leading)
                                        Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
                                    }
                                }
                                HorizontalLine(color: .gray, height: 1.0)
                            }.padding(.leading).offset(x: -geometry.size.width * 0.03)
                        }
                    }
                }
            }
        }.navigationViewStyle(.stack)
    }
}


struct GeneralInfoSubView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @State var senderName: String = ""
    @State var senderCharacteristics: String = ""
    @State var loading: Bool = true
    @FocusState var isFieldFocused: Bool
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        
        if self.loading {
            LottieView(name: "97952-loading-animation-blue").onAppear {
                self.getInfo()
            }
        }
        
        else {
            GeometryReader { geometry in
                VStack {
                    Text("General Info").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading).padding(.leading)
                    Text("Please input some general info:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding().padding(.leading)
                    
                    ScrollView {
                        Text("Sender Name").bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                        TextEditor(text: $senderName).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.35)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(0.75))
                                .focused($isFieldFocused)
                                .offset(x: -20)
                        
                        Text("Sender Characteristics").bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                        TextEditor(text: $senderCharacteristics).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.35)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(0.75))
                                .focused($isFieldFocused)
                                .offset(x: -20)
                    }
                    
                }.offset(x: -15)
            }
        }
    }
    
    func getInfo() {
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            if error == nil {
                let data = doc?.data()
                if data != nil {
                    self.senderName = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME] as? String ?? ""
                    self.senderCharacteristics = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS] as? String ?? ""
                    self.loading = false
                }
            }
        }
    }
    
    func updateInfo() {
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
        [
            Users.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME: self.senderName,
            Users.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS: self.senderCharacteristics
        ]
        )
    }
}


struct BusinessInfoSubView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme
    @FocusState var isFieldFocused: Bool
    @State var businessName: String = ""
    @State var address: String = ""
    @State var industry: String = ""
    @State var loading: Bool = true
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        
        if self.loading {
            LottieView(name: "97952-loading-animation-blue").onAppear {
                self.getInfo()
            }
        }
        
        else {
            GeometryReader { geometry in
                VStack {
                    Text("Business Info").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading).padding(.leading)
                    Text("Please input the following information about your business:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding().padding(.leading)
                    
                    ScrollView {
                        Text("Address").bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                        TextEditor(text: $address).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.25)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(0.75))
                                .focused($isFieldFocused)
                                .offset(x: -20)
                        
                        Text("Business Name").bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                        TextEditor(text: $businessName).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.25)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(0.75))
                                .focused($isFieldFocused)
                                .offset(x: -20)
                        
                        Text("Industry").bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                        TextEditor(text: $industry).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.25)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary).opacity(0.75))
                                .focused($isFieldFocused)
                                .offset(x: -20)
                    }
                    
                }.offset(x: -15)
            }
        }
    }
    
    func getInfo() {
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            if error == nil {
                let data = doc?.data()
                if data != nil {
                    self.address = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_ADDRESS] as? String ?? ""
                    self.businessName = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME] as? String ?? ""
                    self.industry = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY] as? String ?? ""
                    self.loading = false
                }
            }
        }
    }
    
    func updateInfo() {
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
        [
            Users.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_ADDRESS: self.address,
            Users.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME: self.businessName,
            Users.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY: self.industry
        ]
        )
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
