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
        "Business Info": BusinessInfoSubView(),
        "Messager Characteristics": BusinessInfoSubView(),
        "Services & Pricing": BusinessInfoSubView(),
        "Frequently Changing": BusinessInfoSubView(),
        "Specific Respsonses": BusinessInfoSubView()
    ]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
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
                            }.offset(x: -20)
                        }
                    }
                }
            }
        }
    }
}

struct BusinessInfoSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var businessName: String = ""
    @State var location: String = ""
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        GeometryReader { geometry in
            VStack {
                Text("Business Info").bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: geometry.size.width, alignment: .leading)
                Text("Please input the following information about your business:").font(.system(size: 18)).frame(width: geometry.size.width, alignment: .leading).padding()
                InputBoxView(heading: "Business Name", input: $businessName, width: geometry.size.width, height: geometry.size.height, autoCorrect: false).padding(.bottom)
                InputBoxView(heading: "Location", input: $location, width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct InputBoxView: View {
    var heading: String = ""
    @Binding var input: String
    
    let width: CGFloat
    let height: CGFloat
    var autoCorrect: Bool = true
            
    var body: some View {
        VStack {
            Text(heading).frame(width: width, alignment: .leading).font(.system(size: 15)).foregroundColor(.gray)
            
            NeumorphicStyleTextField(textField: TextField("", text: $input), sfName: nil, imageName: nil, textBinding: $input, placeholderText: heading, autoCorrect: autoCorrect).frame(width: width * 0.95).padding(.trailing)
            
//            TextField(heading, text: $input)
//                .padding()
//                .foregroundColor(.white)
//                .background(Color.textBoxGgray)
//                .cornerRadius(6)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 6).stroke(self.isFieldFocused ? .white : .clear, lineWidth: 1)
//                )
//                .frame(width: width * 0.95).padding(.trailing)
//                .focused($isFieldFocused)
                
        }.frame(width: width)
    }
}

struct NeumorphicStyleTextField: View {
    var textField: TextField<Text>
    var sfName: String?
    var imageName: String?
    @Binding var textBinding: String
    let placeholderText: String
    var autoCorrect: Bool
    @State var isTapped: Bool = false
    @FocusState var isFieldFocused: Bool
    
    init(textField: TextField<Text>, sfName: String?, imageName: String?, textBinding: Binding<String>, placeholderText: String, autoCorrect: Bool = true) {
        self.textField = textField
        self.sfName = sfName
        self.imageName = imageName
        _textBinding = textBinding
        self.placeholderText = placeholderText
        self.autoCorrect = autoCorrect
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
            textField.placeholder(when: textBinding.isEmpty) {Text(self.placeholderText).foregroundColor(.white)}.autocorrectionDisabled(!autoCorrect)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.textBoxGgray)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(self.isFieldFocused ? .white : .clear, lineWidth: 1)
            )
            .padding(.trailing)
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
