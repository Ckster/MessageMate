//
//  DynamicDictSubView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/19/23.
//

import SwiftUI
import FirebaseFirestore


struct DynamicDictSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var items: [DoubleInputBoxView] = []
    @State var loading: Bool = true
    @State var itemToDelete: UUID?
    @State var itemStrings: [UUID : [String]] = [:]
    @State var showFillOutFirst: Bool = false
    let keyText: String
    let valueText: String
    let keyHeader: String
    let valueHeader: String
    let promptText: String
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
                        
                        DictHeaderView(header: self.header, promptText: self.promptText, keyHeader: self.keyHeader, valueHeader: self.valueHeader, width: geometry.size.width, textColor: textColor).onChange(of: self.itemToDelete, perform: {newItemId in
                            if newItemId != nil {
                                let deletionIndex = self.items.firstIndex(where: { $0.id == newItemId })
                                if deletionIndex != nil {
                                    self.items.remove(at: deletionIndex!)
                                    self.itemStrings.removeValue(forKey: newItemId!)
                                }
                            }
                        })
                        
                        DynamicDictScrollView(items: $items, itemStrings: $itemStrings, showFillOutFirst: $showFillOutFirst, itemToDelete: $itemToDelete, width: geometry.size.width, height: geometry.size.height, textColor: textColor, keyText: self.keyText, valueText: self.valueText, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect)
                        
                    }.onDisappear(perform: {
                        self.updateItems()
                    })
                    
                    // Tells user they need to fill out all items before adding a new one
                    if self.showFillOutFirst {
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundColor(Color.gray)
                            .frame(width: geometry.size.width * 0.80, height: 100, alignment: .center).offset(x: -20, y: 140).padding()
                            .overlay(
                                VStack {
                                    Text(self.completeBeforeText).font(.body).offset(x: -20, y: 140)
                                }
                        )
                    }
                    
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
                        let newItem = DoubleInputBoxView(keyType: itemType, value: existingItems[itemType]!, deletable: true, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect)
                        newExistingItems.append(newItem)
                        self.itemStrings[newItem.id] = [newItem.type, newItem.value]
                        if itemType == itemTypes.last {
                            self.items = newExistingItems
                            self.loading = false
                        }
                    }
                    
                    if existingItems.count == 0 {
                        let newItem = DoubleInputBoxView(keyType: "", value: "", deletable: false, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: nil, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect)
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
}


struct DynamicDictScrollView: View {
    @Binding var items: [DoubleInputBoxView]
    @Binding var itemStrings: [UUID: [String]]
    @Binding var showFillOutFirst: Bool
    @Binding var itemToDelete: UUID?
    let width: CGFloat
    let height: CGFloat
    let textColor: Color
    let keyText: String
    let valueText: String
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    
    var body: some View {
        ScrollView {
            ScrollViewReader {
                value in
                VStack {
                    ForEach(self.items.sorted { $0.type.first ?? "z" < $1.type.first ?? "z" }, id:\.self.id) {
                        item in
                        
                        let navView = HStack {
                            Text(self.itemStrings[item.id]![0]).frame(width: width * 0.3, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
                            Text(self.itemStrings[item.id]![1]).frame(width: width * 0.55, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
                            Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -10)
                        }
                        
                        NavigationLink(destination: item) {
                            navView
                        }.id(item.id)

                        HorizontalLine(color: .gray)
                    }.padding(.bottom)
                    
                    Image(systemName: "plus.circle").font(.system(size: 45)).onTapGesture {
                        var count = 0
                        for item in self.itemStrings.values {
                            if item[0] == "" || item[1] == "" {
                                count = count + 1
                            }
                        }
                        
                        if count < 1 {
                            let newDB = DoubleInputBoxView(keyType: "", value: "", deletable: true, keyHeader: self.keyText, valueHeader: self.valueText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: true, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCorrect)
                            self.itemStrings[newDB.id] = [newDB.type, newDB.value]
                            self.items.append(newDB)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                value.scrollTo(1)
                            }
                        }
                        else {
                            self.showFillOutFirst = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                self.showFillOutFirst = false
                            }
                        }
                        
                    }.frame(width: width, alignment: .center).offset(x: -20).id(1)
                }
            }
        }
    }
}


struct DictHeaderView: View {
    let header: String
    let promptText: String
    let keyHeader: String
    let valueHeader: String
    let width: CGFloat
    let textColor: Color
    
    var body: some View {
        Text(self.header).bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: width, alignment: .leading).padding(.leading)
        Text(self.promptText).font(.system(size: 18)).frame(width: width, alignment: .leading).padding(.leading).padding(.bottom)
        
        HStack {
            Text(self.keyHeader).bold().font(.system(size: 21)).frame(width: width * 0.3, alignment: .leading)
            Text(self.valueHeader).bold().font(.system(size: 21)).frame(width: width * 0.59, alignment: .leading)
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
    @Binding var inputToDelete: UUID?
    @Binding var inputStrings: [UUID: [String]]
    @FocusState var isFieldFocused: Bool
    let db = Firestore.firestore()
    @State var justAdded: Bool
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    
    init (keyType: String, value: String, deletable: Bool, keyHeader: String, valueHeader: String, inputToDelete: Binding<UUID?>?, inputStrings: Binding<[UUID: [String]]>, justAdded: Bool,
          disableAutoCorrect: Bool, disableAutoCapitalization: Bool) {
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
    }
    
    var body: some View {
        
        let deleteAlert =
            Alert(title: Text("Delete \(keyHeader)"), message: Text("Are you sure you would like to delete this \(keyHeader)?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Delete"), action: {
                self.inputToDelete = self.id
                self.presentationMode.wrappedValue.dismiss()
            }))
        
        GeometryReader {
            geometry in
                VStack {
                    Button(action: {
                        self.showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash.circle").foregroundColor(.red).font(.system(size: 27)) .frame(width: geometry.size.width * 0.8, alignment: .trailing)
                    }.alert(isPresented: $showingDeleteAlert) {
                        deleteAlert
                    }
                    
                    Text(keyHeader).bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                    TextEditor(text: $type).frame(width: geometry.size.width * 0.80, height: geometry.size.height * 0.15)
                        .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary).opacity(0.75))
                            .focused($isFieldFocused)
                    
                    Text(valueHeader).bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                    TextEditor(text: $value).frame(width: geometry.size.width * 0.80, height: geometry.size.height * 0.45)
                        .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary).opacity(0.75))
                            .focused($isFieldFocused).autocorrectionDisabled(self.disableAutoCorrect).autocapitalization(self.disableAutoCorrect ? .none : .sentences)
                    }
                .contentShape(Rectangle())
                    .onTapGesture {
                        self.isFieldFocused = false
                    }
                .onChange(of: self.type) {
                    newType in
                    self.inputStrings[self.id] = [self.type, self.value]
                }.onChange(of: self.value) {
                    newValue in
                    self.inputStrings[self.id] = [self.type, self.value]
                }.onAppear(perform: {
                    self.type = self.inputStrings[self.id]![0]
                    self.value = self.inputStrings[self.id]![1]
                }).onDisappear(perform: {
                    self.justAdded = false
                })
            }
        }
    
    static func ==(lhs: DoubleInputBoxView, rhs: DoubleInputBoxView) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.type)
    }
}

