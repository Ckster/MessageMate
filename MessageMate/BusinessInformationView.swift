//
//  BusinessInformationView.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/23/23.
//

import SwiftUI
import FirebaseFirestore

//"Website: awakenpermanentcosmetics.com. Scheduling appointment link: https://koalendar.com/e/schedule-my-pmu"

struct BusinessInformationView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.colorScheme) var colorScheme

    let subViewDict: Dictionary<String, AnyView> = [
        "General": AnyView(GeneralInfoSubView()),
        "Business Info": AnyView(BusinessInfoSubView()),
        "Links": AnyView(BusinessLinksSubView()),
        "Products and Services": AnyView(ProductsAndServicesSubView()),
     //   "Services": BusinessInfoSubView(),
//        "FAQs": BusinessInfoSubView(),
//        "Do Not": BusinessInfoSubView(),
//        "Frequently Changing": BusinessInfoSubView()
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
                    Text("General Info").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading)
                    Text("Please input some general info:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding()
                    
                    InputBoxView(heading: "Sender Name", placeholderText: self.senderName, input: $senderName, width: geometry.size.width * 0.9, height: geometry.size.height, fontSize: 15).padding(.bottom)
                    InputBoxView(heading: "Sender Characterstics", placeholderText: self.senderCharacteristics, input: $senderCharacteristics, width: geometry.size.width * 0.9, height: geometry.size.height, fontSize: 15, autoCorrect: false).padding(.bottom)
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
                    Text("Business Info").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading)
                    Text("Please input the following information about your business:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding()
                    
                    InputBoxView(heading: "Address", placeholderText: self.address, input: $address, width: geometry.size.width * 0.9, height: geometry.size.height, fontSize: 15).padding(.bottom)
                    InputBoxView(heading: "Business Name", placeholderText: self.businessName, input: $businessName, width: geometry.size.width * 0.9, height: geometry.size.height, fontSize: 15, autoCorrect: false).padding(.bottom)
                    InputBoxView(heading: "Industry", placeholderText: self.industry, input: $industry, width: geometry.size.width * 0.9, height: geometry.size.height, fontSize: 15, autoCorrect: false)
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

struct BusinessLinksSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var links: [DoubleInputBoxView] = []
    @State var businessName: String = ""
    @State var location: String = ""
    @State var loading: Bool = true
    @State var linkToDelete: UUID?
    @State var linkStrings: [UUID : [String]] = [:]
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        GeometryReader {
            geometry in
            if self.loading {
                LottieView(name: "97952-loading-animation-blue").onAppear {
                    self.getLinks()
                }
            }
            else {
                VStack {
                    Text("Links").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading).padding(.leading)
                    Text("Please add links to your businesse's web services:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding(.leading).onChange(of: self.linkToDelete, perform: {newLinkId in
                        let deletionIndex = self.links.firstIndex(where: { $0.id == newLinkId })
                        if deletionIndex != nil {
                            self.links.remove(at: deletionIndex!)
                        }
                    })
                    
                    ScrollView {
                        ScrollViewReader {
                            value in
                            VStack {
                                ForEach(self.links, id:\.self.id) {
                                    link in
                                    NavigationLink(destination: link) {
                                        HStack {
                                            Text(self.linkStrings[link.id]![0]).frame(width: geometry.size.width * 0.3, alignment: .leading).foregroundColor(Color.white).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
                                            Text(self.linkStrings[link.id]![1]).frame(width:geometry.size.width * 0.55, alignment: .leading).foregroundColor(Color.white).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
                                            Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
                                        }
                                    }.id(link.id)
                                    HorizontalLine(color: .gray)
                                }
                                
                                Image(systemName: "plus.circle").font(.system(size: 30)).onTapGesture {
                                    let newDB = DoubleInputBoxView(keyType: "", value: "", deletable: true, linkToDelete: $linkToDelete, linkStrings: $linkStrings)
                                    self.linkStrings[newDB.id] = [newDB.type, newDB.value]
                                    self.links.append(newDB)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        value.scrollTo(1)
                                    }
                                }.frame(width: geometry.size.width, alignment: .center).id(1)
                            }
                        }
                    }
                }
                .onDisappear(perform: {
                    self.updateLinks()
                })
            }
        }.onAppear(perform: {
            print("ON APPEARING")
            for linkS in self.linkStrings {
                for linkView in self.links {
                    if linkView.id == linkS.key {
                        print("CHANGING")
                        linkView.type = linkS.value[0]
                        linkView.value = linkS.value[1]
                    }
                }
            }
        })
    }
    
    func getLinks() {
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            print("Got Document")
            if error == nil {
                print("not nil")
                let data = doc?.data()
                if data != nil {
                    print("Data not nil")
                    let existingLinks = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS] as? [String: String]
                    
                    if existingLinks != nil {
                        var newExistingLinks: [DoubleInputBoxView] = []
                        let urlTypes = Array(existingLinks!.keys)
                        
                        for linkType in urlTypes {
                            let newLink = DoubleInputBoxView(keyType: linkType, value: existingLinks![linkType]!, deletable: true, linkToDelete: $linkToDelete, linkStrings: $linkStrings)
                            newExistingLinks.append(newLink)
                            self.linkStrings[newLink.id] = [newLink.type, newLink.value]
                            if linkType == urlTypes.last {
                                self.links = newExistingLinks
                                self.loading = false
                            }
                        }
                        
                        if existingLinks?.count == 0 {
                            let newLink = DoubleInputBoxView(keyType: "", value: "", deletable: false, linkToDelete: nil, linkStrings: $linkStrings)
                            self.linkStrings[newLink.id] = [newLink.type, newLink.value]
                            self.links = [newLink]
                            self.loading = false
                        }
                    }
                }
            }
        }
    }
    
    func updateLinks() {
        var newLinks: [String: String] = [:]
        for newLink in self.linkStrings.values {
            if newLink[0] != "" {
                newLinks[typeToKey(input: newLink[0])] = newLink[1]
            }
        }
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [Users.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS: newLinks]
        )
    }
}


struct ProductsAndServicesSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var products: [DoubleInputBoxView] = []
    @State var businessName: String = ""
    @State var location: String = ""
    @State var loading: Bool = true
    @State var productsToDelete: UUID?
    @State var productStrings: [UUID : [String]] = [:]
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        GeometryReader {
            geometry in
            if self.loading {
                LottieView(name: "97952-loading-animation-blue")
//                    .onAppear {
//                        self.getLinks()
//                }
            }
            else {
                VStack {
                    Text("Services").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading).padding(.leading)
                    Text("Description of service :").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding(.leading).onChange(of: self.productsToDelete, perform: {newProductId in
                        let deletionIndex = self.products.firstIndex(where: { $0.id == newProductId })
                        if deletionIndex != nil {
                            self.products.remove(at: deletionIndex!)
                        }
                    })
                    
                    ScrollView {
                        ScrollViewReader {
                            value in
                            VStack(spacing: 70) {
                                ForEach(self.products, id:\.self.id) {
                                    link in
                                    link.padding(.leading).id(link.id)
                                }
                                Image(systemName: "plus.circle").font(.system(size: 30)).onTapGesture {
                                    let newDB = DoubleInputBoxView(keyType: "", value: "", deletable: true, linkToDelete: $productsToDelete, linkStrings: $productStrings)
//                                    self.linkStrings[newDB.id] = [newDB.type, newDB.value]
//                                    self.links.append(newDB)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        value.scrollTo(1)
                                    }
                                }.frame(maxWidth: .infinity).id(1)
                            }
                        }
                    }
                }
//                .onDisappear(perform: {
//                    self.updateLinks()
//                })
            }
        }
    }
    
//    func getProdcuts() {
//        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
//            doc, error in
//            print("Got Document")
//            if error == nil {
//                print("not nil")
//                let data = doc?.data()
//                if data != nil {
//                    print("Data not nil")
//                    let existingProducts = data![Users.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS] as? [String: String]
//
//                    if existingProducts != nil {
//                        var newExistingLinks: [DoubleInputBoxView] = []
//                        let urlTypes = Array(existingProducts!.keys)
//
//                        for linkType in urlTypes {
//                            let newLink = DoubleInputBoxView(keyType: linkType, value: existingProducts![linkType]!, deletable: true, linkToDelete: $productsToDelete, linkStrings: $productStrings)
//                            newExistingLinks.append(newLink)
//                            self.productStrings[newLink.id] = [newLink.type, newLink.value]
//                            if linkType == urlTypes.last {
//                                self.products = newExistingLinks
//                                self.loading = false
//                            }
//                        }
//
//                        if existingLinks?.count == 0 {
//                            let newLink = DoubleInputBoxView(keyType: "", value: "", deletable: false, $productsToDelete: nil, linkStrings: $productStrings)
//                            self.productStrings[newLink.id] = [newLink.type, newLink.value]
//                            self.products = [newLink]
//                            self.loading = false
//                        }
//                    }
//                }
//            }
//        }
//    }
    
//    func updateLinks() {
//        var newLinks: [String: String] = [:]
//        for newLink in self.linkStrings.values {
//            if newLink[0] != "" {
//                newLinks[typeToKey(input: newLink[0])] = newLink[1]
//            }
//        }
//        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
//            [Users.collections.BUSINESS_INFO.documents.FIELDS.fields.LINKS: newLinks]
//        )
//    }
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

struct navLinkLabel: View {
    @Binding var key: String
    @Binding var value: String
    let width: CGFloat
        
    var body: some View {
        HStack {
            Text(key).frame(width: width * 0.3, alignment: .leading).foregroundColor(Color.white).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
            Text(value).frame(width: width * 0.55, alignment: .leading).foregroundColor(Color.white).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
            Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -5)
        }
    }
}


struct DoubleInputBoxView: View, Equatable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    let id = UUID()
    var keyType: String
    let deletable: Bool
    @State var type: String
    @State var value: String
    @Binding var linkToDelete: UUID?
    @Binding var linkStrings: [UUID: [String]]
    let db = Firestore.firestore()
    
    init (keyType: String, value: String, deletable: Bool, linkToDelete: Binding<UUID?>?, linkStrings: Binding<[UUID: [String]]>) {
        self.keyType = keyType
        self.deletable = deletable
        _type = State(initialValue: keyToType(input: keyType))
        _value = State(initialValue: value)
        self._linkToDelete = linkToDelete ?? Binding.constant(nil)
        self._linkStrings = linkStrings
    }
    
    var body: some View {
        GeometryReader {
            geometry in
            HStack {
                InputBoxView(input: $type, width: geometry.size.width * 0.35, height: geometry.size.height, fontSize: 13).autocorrectionDisabled(true).autocapitalization(.none)
                InputBoxView(input: $value, width: geometry.size.width * 0.45, height: geometry.size.height, fontSize: 13).autocorrectionDisabled(true).autocapitalization(.none)
                
                if self.deletable {
                    Image(systemName: "minus.circle").font(.system(size: 25)).foregroundColor(.red).frame(width: geometry.size.width * 0.05).offset(y: 5).onTapGesture {
                        self.linkStrings.removeValue(forKey: self.id)
                        self.linkToDelete = self.id
                    }
                }
            }.onChange(of: self.type) {
                newType in
                self.linkStrings[self.id] = [self.type, self.value]
            }.onChange(of: self.value) {
                newValue in
                self.linkStrings[self.id] = [self.type, self.value]
            }
        }
    }
    
    static func ==(lhs: DoubleInputBoxView, rhs: DoubleInputBoxView) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.type)
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
