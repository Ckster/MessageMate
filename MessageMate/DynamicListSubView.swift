//
//  DynamicListSubView.swift
//  MessageMate
//
//  Created by Erick Verleye on 2/19/23.
//

import SwiftUI
import FirebaseFirestore


struct DynamicListSubView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @State var items: [SingleInputBoxView] = []
    @State var loading: Bool = true
    @State var itemToDelete: UUID?
    @State var itemStrings: [UUID : String] = [:]
    let listHeaderText: String
    let inputText: String
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
                        
                        ListHeaderView(header: self.header, promptText: self.promptText, listHeaderText: self.listHeaderText, width: geometry.size.width, textColor: textColor).onChange(of: self.itemToDelete, perform: {newItemId in
                            if newItemId != nil {
                                let deletionIndex = self.items.firstIndex(where: { $0.id == newItemId })
                                if deletionIndex != nil {
                                    self.items.remove(at: deletionIndex!)
                                    self.itemStrings.removeValue(forKey: newItemId!)
                                }
                            }
                        })
                        DynamicListScrollView(items: $items, itemStrings: $itemStrings, itemToDelete: $itemToDelete, width: geometry.size.width, height: geometry.size.height, textColor: textColor, listHeader: self.listHeaderText, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCapitalization, inputText: inputText, firebaseItemsField: self.firebaseItemsField)
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
                    let existingItems = data![self.firebaseItemsField] as? [String] ?? []
                    
                    var newExistingItems: [SingleInputBoxView] = []
                    
                    for item in existingItems {
                        let newItem = SingleInputBoxView(item: item, deletable: true, listHeader: self.listHeaderText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCapitalization, inputText: inputText, firebaseItemsField: self.firebaseItemsField)
                        newExistingItems.append(newItem)
                        self.itemStrings[newItem.id] = newItem.item
                        if item == existingItems.last {
                            self.items = newExistingItems
                            self.loading = false
                        }
                    }
                    
                    if existingItems.count == 0 {
                        let newItem = SingleInputBoxView(item: "", deletable: false, listHeader: self.listHeaderText, inputToDelete: nil, inputStrings: $itemStrings, justAdded: false, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCapitalization, inputText: inputText, firebaseItemsField: self.firebaseItemsField)
                        self.itemStrings[newItem.id] = newItem.item
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
}

struct ListHeaderView: View {
    let header: String
    let promptText: String
    let listHeaderText: String
    let width: CGFloat
    let textColor: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(self.header).font(Font.custom(BOLD_FONT, size: 25)).foregroundColor(textColor).frame(width: width, alignment: .leading).padding(.leading).padding(.bottom)
            Text(self.promptText).font(Font.custom(REGULAR_FONT, size: 18)).frame(width: width * 0.95, alignment: .leading).padding(.leading).padding(.bottom)
            Text(self.listHeaderText).font(Font.custom(BOLD_FONT, size: 21)).frame(width: width, alignment: .leading).padding(.leading)
        }
    }
}


struct DynamicListScrollView: View {
    @Binding var items: [SingleInputBoxView]
    @Binding var itemStrings: [UUID: String]
    @Binding var itemToDelete: UUID?
    @State private var viewToNavigateTo: UUID? = nil
    let width: CGFloat
    let height: CGFloat
    let textColor: Color
    let listHeader: String
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    let inputText: String
    let firebaseItemsField: String
    
    var body: some View {
        ScrollView {
            ScrollViewReader {
                value in
                VStack {
                    ForEach(self.items.sorted { $0.item.first ?? "z" < $1.item.first ?? "z" }, id:\.self.id) {
                        item in
                        
                        let navView = HStack {
                            Text(self.itemStrings[item.id]!).frame(width: width * 0.8, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(Font.custom(REGULAR_FONT, size: 21)).multilineTextAlignment(.leading)
                            Image(systemName: "chevron.right").foregroundColor(.gray).imageScale(.small).offset(x: -10)
                        }
                        
                        NavigationLink(destination: item.navigationBarBackButtonHidden(true), tag: item.id, selection: self.$viewToNavigateTo) {
                            navView
                        }.id(item.id)

                        HorizontalLine(color: .gray)
                    }.padding(.bottom)
                    
                    Image(systemName: "plus.circle").font(.system(size: 45)).onTapGesture {
                        
                        let newSB = SingleInputBoxView(item: "", deletable: true, listHeader: self.listHeader, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: true, disableAutoCorrect: self.disableAutoCorrect, disableAutoCapitalization: self.disableAutoCapitalization, inputText: inputText, firebaseItemsField: self.firebaseItemsField)
                        self.viewToNavigateTo = newSB.id
                        self.itemStrings[newSB.id] = newSB.item
                        self.items.append(newSB)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            value.scrollTo(1)
                        }
                        
                    }.frame(width: width, alignment: .center).id(1)
                }
            }
        }
    }
}


struct SingleInputBoxView: View, Equatable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var session: SessionStore
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    let id = UUID()
    let deletable: Bool
    let listHeader: String

    @State var item: String
    @State var showingDeleteAlert: Bool = false
    @Binding var inputToDelete: UUID?
    @Binding var inputStrings: [UUID: String]
    @FocusState var isFieldFocused: Bool
    let db = Firestore.firestore()
    @State var justAdded: Bool
    let firebaseItemsField: String
    let disableAutoCorrect: Bool
    let disableAutoCapitalization: Bool
    let inputText: String
    
    init (item: String, deletable: Bool, listHeader: String, inputToDelete: Binding<UUID?>?, inputStrings: Binding<[UUID: String]>, justAdded: Bool, disableAutoCorrect: Bool, disableAutoCapitalization: Bool, inputText: String, firebaseItemsField: String) {
        self.deletable = deletable
        self.listHeader = listHeader
        _item = State(initialValue: keyToType(input: item))
        self._inputToDelete = inputToDelete ?? Binding.constant(nil)
        self._inputStrings = inputStrings
        _justAdded = State(initialValue: justAdded)
        self.disableAutoCorrect = disableAutoCorrect
        self.disableAutoCapitalization = disableAutoCapitalization
        self.inputText = inputText
        self.firebaseItemsField = firebaseItemsField
    }
    
    var body: some View {
        
        let deleteAlert =
        Alert(title: Text("Delete \(inputText)").font(Font.custom(REGULAR_FONT, size: 25)), message: Text("Are you sure you would like to delete this \(inputText)?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Delete"), action: {
                self.inputToDelete = self.id
                
                // Remove the key / value pair from local storage and then firebase
                self.removeItem()
                self.updateItems()
                
                self.presentationMode.wrappedValue.dismiss()
                }
            )
        )
        
        GeometryReader {
            geometry in
                VStack {
                    HStack {
                        Button(action: {
                            self.showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash.circle").foregroundColor(.red).font(.system(size: 28)) .frame(width: geometry.size.width * 0.70, alignment: .trailing)
                        }.alert(isPresented: $showingDeleteAlert) {
                            deleteAlert
                        }
                        
                        Button(action: {
                            if self.item == "" {
                                self.inputToDelete = self.id
                                self.presentationMode.wrappedValue.dismiss()
                            }
                                                            
                            else {
                                self.updateItems()
                                self.presentationMode.wrappedValue.dismiss()
                            }
                            
                        }) {
                            Text("Done").frame(width: geometry.size.width * 0.30, alignment: .center).font(.system(size: 23))
                        }
                    }
                    
                    Text(listHeader).font(Font.custom(BOLD_FONT, size: 21)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading)
                        .padding(.leading)
                    TextEditor(text: $item).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.15)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary).opacity(0.75))
                        .focused($isFieldFocused)
                        .autocorrectionDisabled(self.disableAutoCorrect)
                        .autocapitalization(self.disableAutoCorrect ? .none : .sentences)
                    
                    }
                .contentShape(Rectangle())
                .onTapGesture {
                    self.isFieldFocused = false
                }
                .onAppear(perform: {
                    self.item = self.inputStrings[self.id]!
                })
            }
        }
    
    func removeItem() {
        self.inputStrings.removeValue(forKey: self.id)
    }
    
    func updateItems() {
        var newItems: [String] = []
        self.inputStrings[self.id] = self.item
        for newItem in self.inputStrings.values {
            if newItem != "" {
                newItems.append(newItem)
            }
        }
        
        self.db.collection(Pages.name).document("\(self.session.selectedPage!.id)/\(Pages.collections.BUSINESS_INFO.name)/\(Pages.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [self.firebaseItemsField: newItems]
        )
    }
    
    static func ==(lhs: SingleInputBoxView, rhs: SingleInputBoxView) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.item)
    }
}
