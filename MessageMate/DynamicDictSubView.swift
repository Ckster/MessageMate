//
//  DynamicDictSubView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/19/23.
//

import SwiftUI
import FirebaseFirestore

// TODO: Variable names are all messed up, update them so they make more sense

struct DynamicDictSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var items: [DoubleInputBoxView] = []
    @State var loading: Bool = true
    @State var itemToDelete: UUID?
    @State var itemStrings: [UUID : [String]] = [:]
    @State var showingPopup: Bool = false
    @State var workingWebsiteURLTextEditors: [websiteURLTextEditor] = []
    @State var urlValueDict: [UUID: String]
    @State var crawlingWebpage: Bool = false
    let keyText: String
    let valueText: String
    let keyHeader: String
    let valueHeader: String
    let promptText: String
    let websiteLinkPromptText: String?
    let websiteSection: String?
    let header: String
    let completeBeforeText: String
    let firebaseItemsField: String
    let db = Firestore.firestore()
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        GeometryReader {
            geometry in
            
            if self.loading {
                LottieView(name: "Loading-2").onAppear {
                    self.getItems()
                }
            }
            
            else {
                ZStack {
    
                    // The scroll view with all items displayed
                    VStack {
                        
                        DictHeaderView(header: self.header, promptText: self.promptText, websiteLinkPromptText: websiteLinkPromptText, keyHeader: self.keyHeader, valueHeader: self.valueHeader, width: geometry.size.width, height: geometry.size.height, textColor: textColor, showingPopup: $showingPopup)
                            .onChange(of: self.itemToDelete, perform: {
                                newItemId in
                                if newItemId != nil {
                                    let deletionIndex = self.items.firstIndex(where: { $0.id == newItemId })
                                    if deletionIndex != nil {
                                        
                                        // Remove the view from list of views
                                        self.items.remove(at: deletionIndex!)
                                    }
                                }
                            }
                        )
                        
                        if self.crawlingWebpage {
                            VStack {
                                Text("Retrieving information from webpage. This may take a moment ...").font(Font.custom(BOLD_FONT, size: 20))
                                LottieView(name: "Loading-2").frame(width: 300, height: 300)
                            }.onAppear(perform: {
                                getCrawlerResults {
                                    self.crawlingWebpage = false
                                }
                            })
                            .padding(.top)
                        }
                        
                        else {
                            DynamicDictScrollView(items: $items, itemStrings: $itemStrings, itemToDelete: $itemToDelete, width: geometry.size.width, height: geometry.size.height, textColor: textColor, keyText: self.keyText, valueText: self.valueText, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect, firebaseItemsField: self.firebaseItemsField).allowsHitTesting(!showingPopup)
                        }
                        
                    }
                    .opacity(self.showingPopup ? 0.15 : 1.0)
                    
                }.popup(isPresented: $showingPopup) {
                    multipleInputLinkPopup(urlTextEditors: $workingWebsiteURLTextEditors, urlValueDict: self.$urlValueDict, showingPopup: $showingPopup, crawlingWebpage: $crawlingWebpage, height: geometry.size.height, width: geometry.size.width)
                }
            }
        }
    }
    
    func getItems() {
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            if error == nil {
                let data = doc?.data()
                if data != nil {
                    let existingItems = data![self.firebaseItemsField] as? [String: String] ?? [:]
                    
                    var newExistingItems: [DoubleInputBoxView] = []
                    let itemTypes = Array(existingItems.keys)
                    
                    for itemType in itemTypes {
                        let newItem = DoubleInputBoxView(keyType: itemType, value: existingItems[itemType]!, deletable: true, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect, firebaseItemsField: self.firebaseItemsField)
                        newExistingItems.append(newItem)
                        self.itemStrings[newItem.id] = [newItem.type, newItem.value]
                        if itemType == itemTypes.last {
                            self.items = newExistingItems
                            self.loading = false
                        }
                    }
                    
                    if existingItems.count == 0 {
                        let newItem = DoubleInputBoxView(keyType: "", value: "", deletable: false, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: nil, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect, firebaseItemsField: self.firebaseItemsField)
                        self.itemStrings[newItem.id] = [newItem.type, newItem.value]
                        self.items = [newItem]
                        self.loading = false
                    }
                    
                }
                else {
                    // TODO: Show the user an error here
                }
            }
        }
    }
    
    func updateItems() {
        var newItems: [String: String] = [:]
    
        for newItem in self.itemStrings.values {
            if newItem[0] != "" {
                newItems[typeToKey(input: newItem[0])] = newItem[1]
            }
        }
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [self.firebaseItemsField: newItems]
        )
    }
    
    func getCrawlerResults(completion: @escaping () -> Void) {
        webcrawlRequest(section: self.websiteSection!, urls: self.urlValueDict.values.map { $0 }) {
            response in
            let responseData: [String: String] = response as? [String: String] ?? ["" : ""]  // TODO: Add alert if empty
            var newExistingItems: [DoubleInputBoxView] = []
            let itemTypes = Array(responseData.keys)
            
            for itemType in itemTypes {
                let newItem = DoubleInputBoxView(keyType: itemType, value: responseData[itemType]!, deletable: true, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect, firebaseItemsField: self.firebaseItemsField)
                newExistingItems.append(newItem)
                self.itemStrings[newItem.id] = [newItem.type, newItem.value]
                if itemType == itemTypes.last {
                    self.items = newExistingItems
                    self.loading = false
                }
            }

            self.updateItems()
            completion()
        }
    }
}


struct DynamicDictScrollView: View {
    @Binding var items: [DoubleInputBoxView]
    @Binding var itemStrings: [UUID: [String]]
    @Binding var itemToDelete: UUID?
    @State private var viewToNavigateTo: UUID? = nil
    let width: CGFloat
    let height: CGFloat
    let textColor: Color
    let keyText: String
    let valueText: String
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    let firebaseItemsField: String
    
    var body: some View {
        ScrollView {
            ScrollViewReader {
                value in
                VStack {
                    ForEach(self.items.sorted { $0.type.first ?? "z" < $1.type.first ?? "z" }, id:\.self.id) {
                        item in
                        let navView = HStack {
                            Text(self.itemStrings[item.id]![0]).frame(width: width * 0.3, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(Font.custom(REGULAR_FONT, size: 21)).multilineTextAlignment(.leading)
                            Text(self.itemStrings[item.id]![1]).frame(width: width * 0.55, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(Font.custom(REGULAR_FONT, size: 21)).multilineTextAlignment(.leading)
                            Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -10)
                        }
                        
                        NavigationLink(destination: item.navigationBarBackButtonHidden(true), tag: item.id, selection: self.$viewToNavigateTo) {
                            navView
                        }
                        .id(item.id)

                        HorizontalLine(color: .gray)
                    }.padding(.bottom)
                    
                    Image(systemName: "plus.circle").font(.system(size: 45)).onTapGesture {
                        
                        let newDB = DoubleInputBoxView(keyType: "", value: "", deletable: true, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: true, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect, firebaseItemsField: self.firebaseItemsField)
                        self.viewToNavigateTo = newDB.id
                        self.itemStrings[newDB.id] = [newDB.type, newDB.value]
                        self.items.append(newDB)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            value.scrollTo(1)
                        }
                       
                    }.frame(width: width, alignment: .center).id(1)
                }
            }
        }
    }
}


struct DictHeaderView: View {
    let header: String
    let promptText: String
    let websiteLinkPromptText: String?
    let keyHeader: String
    let valueHeader: String
    let width: CGFloat
    let height: CGFloat
    let textColor: Color
    @Binding var showingPopup: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .center) {
            Text(self.header).font(Font.custom(BOLD_FONT, size: 25)).foregroundColor(textColor).frame(width: width * 0.9, alignment: .leading).padding(.bottom)
            
            if self.websiteLinkPromptText != nil {
                Text(self.websiteLinkPromptText!).font(Font.custom(REGULAR_FONT, size: 18)).frame(width: width * 0.9, alignment: .leading).padding(.bottom)
                Button(action: {self.showingPopup = true}) {
                    Text("Autofill info with webpage(s)")
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
                .frame(width: width * 0.9, height: height * 0.075)
                .padding(.bottom).padding(.top)
                .allowsHitTesting(!showingPopup)
            }
            
            Text(self.promptText).font(Font.custom(REGULAR_FONT, size: 18)).frame(width: width * 0.9, alignment: .leading).padding(.bottom)
            
            HStack {
                Text(self.keyHeader).font(Font.custom(BOLD_FONT, size: 21)).frame(width: width * 0.3, alignment: .leading)
                Text(self.valueHeader).font(Font.custom(BOLD_FONT, size: 21)).frame(width: width * 0.59, alignment: .leading)
            }.padding(.leading)
        }
    }
}


struct DoubleInputBoxView: View, Equatable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    let id = UUID()
    var keyType: String
    let deletable: Bool
    let keyHeader: String
    let valueHeader: String
    @State var type: String
    @State var value: String
    @State var showingDeleteAlert: Bool = false
    @State var showFillOutBothFields: Bool = false
    @Binding var inputToDelete: UUID?
    @Binding var inputStrings: [UUID: [String]]
    @FocusState var isFieldFocused: Bool
    let db = Firestore.firestore()
    @State var justAdded: Bool
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    let firebaseItemsField: String
    
    init (keyType: String, value: String, deletable: Bool, keyHeader: String, valueHeader: String, inputToDelete: Binding<UUID?>?, inputStrings: Binding<[UUID: [String]]>, justAdded: Bool,
          disableAutoCorrect: Bool, disableAutoCapitalization: Bool, firebaseItemsField: String) {
        self.keyType = keyType
        self.deletable = deletable
        self.keyHeader = keyHeader
        self.valueHeader = valueHeader
        _type = State(initialValue: keyToType(input: keyType))
        _value = State(initialValue: value)
        self._inputToDelete = inputToDelete ?? Binding.constant(nil)
        self._inputStrings = inputStrings
        _justAdded = State(initialValue: justAdded)
        self.disableAutoCorrect = disableAutoCorrect
        self.disableAutoCapitalization = disableAutoCapitalization
        self.firebaseItemsField = firebaseItemsField
    }
    
    var body: some View {
        
        let deleteAlert =
        Alert(title: Text("Delete \(keyHeader)").font(Font.custom(REGULAR_FONT, size: 21)), message: Text("Are you sure you would like to delete this \(keyHeader)?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Delete"), action: {
            self.inputToDelete = self.id
            
            // Remove the key / value pair from local storage and then firebase
            self.removeItem()
            self.updateItems()
            
            self.presentationMode.wrappedValue.dismiss()
        }))
        
        GeometryReader {
            geometry in
        
                VStack(alignment: .center) {
                    HStack {
                        Button(action: {
                            self.showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash.circle").foregroundColor(.red).font(.system(size: 28)) .frame(width: geometry.size.width * 0.70, alignment: .trailing)
                        }.alert(isPresented: $showingDeleteAlert) {
                            deleteAlert
                        }
                        
                        Button(action: {
                            if self.type == "" && self.value == "" {
                                self.inputToDelete = self.id
                                self.presentationMode.wrappedValue.dismiss()
                            }
                            else {
                                
                                if (self.type == "" || self.value == "") {
                                    self.showFillOutBothFields = true
                                }
                                
                                else {
                                    self.updateItems()
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }) {
                            Text("Done").frame(width: geometry.size.width * 0.30, alignment: .center).font(.system(size: 23))
                        }
                    }
                    
                    Text(keyHeader).font(Font.custom(BOLD_FONT, size: 20)).frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.10, alignment: .leading).minimumScaleFactor(0.2)
                    GenericDynamicHeightTextBox(text: $type).frame(width: geometry.size.width * 0.80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                        .focused($isFieldFocused)
                    
                    Text(valueHeader).font(Font.custom(BOLD_FONT, size: 20)).frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.10, alignment: .leading).minimumScaleFactor(0.2)
                    GenericDynamicHeightTextBox(text: $value).frame(width: geometry.size.width * 0.80)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary).opacity(1))
                        .focused($isFieldFocused).autocorrectionDisabled(self.disableAutoCorrect).autocapitalization(self.disableAutoCorrect ? .none : .sentences)
                    
                    if self.showFillOutBothFields {
                        VStack(alignment: .center) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(Color("Purple"))
                            .frame(width: geometry.size.width * 0.90, height: 100, alignment: .center).padding()
                            .overlay(
                                Text("Please fill out both fields").font(Font.custom(REGULAR_FONT, size: 25))
                            )
                            Spacer()
                        }.onAppear(perform: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                self.showFillOutBothFields = false
                            }
                        })
                    }
                    
                    Spacer()
                }
                .frame(height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    self.isFieldFocused = false
                }
                .onAppear(perform: {
                    self.type = self.inputStrings[self.id]![0]
                    self.value = self.inputStrings[self.id]![1]
                })
            }
        
    }
    
    func removeItem() {
        self.inputStrings.removeValue(forKey: self.id)
    }
    
    func updateItems() {
        var newItems: [String: String] = [:]
        self.inputStrings[self.id] = [self.type, self.value]
        for newItem in self.inputStrings.values {
            if newItem[0] != "" {
                newItems[typeToKey(input: newItem[0])] = newItem[1]
            }
        }
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [self.firebaseItemsField: newItems]
        )
    }
    
    static func ==(lhs: DoubleInputBoxView, rhs: DoubleInputBoxView) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.type)
    }
}

