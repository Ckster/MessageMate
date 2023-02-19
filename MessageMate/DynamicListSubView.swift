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
    @State var showFillOutFirst: Bool = false
    let listHeaderText: String
    let inputText: String
    let promptText: String
    let header: String
    let completeBeforeText: String
    let firebaseItemsField: String
    let db = Firestore.firestore()
    
    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color.black
        GeometryReader {
            geometry in
            
            if self.loading {
                LottieView(name: "97952-loading-animation-blue").onAppear {
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
                        
                        DynamicListScrollView(items: $items, itemStrings: $itemStrings, showFillOutFirst: $showFillOutFirst, itemToDelete: $itemToDelete, width: geometry.size.width, height: geometry.size.height, textColor: textColor, listHeader: self.listHeaderText)
                        
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
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").getDocument() {
            doc, error in
            print("Got Document")
            if error == nil {
                print("not nil")
                let data = doc?.data()
                if data != nil {
                    print("Data not nil")
                    let existingItems = data![self.firebaseItemsField] as? [String]
                    
                    if existingItems != nil {
                        var newExistingItems: [SingleInputBoxView] = []
                        
                        for item in existingItems! {
                            let newItem = SingleInputBoxView(item: item, deletable: true, listHeader: self.listHeaderText, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: false)
                            newExistingItems.append(newItem)
                            self.itemStrings[newItem.id] = newItem.item
                            if item == existingItems!.last {
                                self.items = newExistingItems
                                self.loading = false
                            }
                        }
                        
                        if existingItems!.count == 0 {
                            let newItem = SingleInputBoxView(item: "", deletable: false, listHeader: self.listHeaderText, inputToDelete: nil, inputStrings: $itemStrings, justAdded: false)
                            self.itemStrings[newItem.id] = newItem.item
                            self.items = [newItem]
                            self.loading = false
                        }
                    }
                }
            }
        }
    }
    
    func updateItems() {
        var newItems: [String] = []
        for newItem in self.itemStrings.values {
            if newItem != "" {
                newItems.append(newItem)
            }
        }
        self.db.collection(Users.name).document("\(self.session.user.uid!)/\(Users.collections.BUSINESS_INFO.name)/\(Users.collections.BUSINESS_INFO.documents.FIELDS.name)").updateData(
            [self.firebaseItemsField: newItems]
        )
    }
}

struct ListHeaderView: View {
    let header: String
    let promptText: String
    let listHeaderText: String
    let width: CGFloat
    let textColor: Color
    
    var body: some View {
        VStack {
            Text(self.header).bold().foregroundColor(textColor).font(.system(size: 25)).frame(width: width, alignment: .leading).padding(.leading)
            Text(self.promptText).font(.system(size: 18)).frame(width: width, alignment: .leading).padding(.leading).padding(.bottom)
            Text(self.listHeaderText).bold().font(.system(size: 21)).frame(width: width, alignment: .leading).padding(.leading)
        }
    }
}


struct DynamicListScrollView: View {
    @Binding var items: [SingleInputBoxView]
    @Binding var itemStrings: [UUID: String]
    @Binding var showFillOutFirst: Bool
    @Binding var itemToDelete: UUID?
    let width: CGFloat
    let height: CGFloat
    let textColor: Color
    let listHeader: String
    
    var body: some View {
        ScrollView {
            ScrollViewReader {
                value in
                VStack {
                    ForEach(self.items.sorted { $0.item.first ?? "z" < $1.item.first ?? "z" }, id:\.self.id) {
                        item in
                        
                        let navView = HStack {
                            Text(self.itemStrings[item.id]!).frame(width: width * 0.8, alignment: .leading).foregroundColor(textColor).lineLimit(5).font(.system(size: 21)).multilineTextAlignment(.leading)
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
                            if item == "" {
                                count = count + 1
                            }
                        }
                        
                        if count < 1 {
                            let newSB = SingleInputBoxView(item: "", deletable: true, listHeader: self.listHeader, inputToDelete: $itemToDelete, inputStrings: $itemStrings, justAdded: true)
                            self.itemStrings[newSB.id] = newSB.item
                            self.items.append(newSB)
                            
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
    
    init (item: String, deletable: Bool, listHeader: String, inputToDelete: Binding<UUID?>?, inputStrings: Binding<[UUID: String]>, justAdded: Bool) {
        self.deletable = deletable
        self.listHeader = listHeader
        _item = State(initialValue: keyToType(input: item))
        self._inputToDelete = inputToDelete ?? Binding.constant(nil)
        self._inputStrings = inputStrings
        _justAdded = State(initialValue: justAdded)
    }
    
    var body: some View {
        
        let deleteAlert =
            Alert(title: Text("Delete Link"), message: Text("Are you sure you would like to delete this link?"), primaryButton: .default(Text("Cancel")), secondaryButton: .default(Text("Delete"), action: {
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
                    
                    Text(listHeader).bold().font(.system(size: 20)).frame(width: geometry.size.width, height: geometry.size.height * 0.10, alignment: .leading).padding(.leading)
                    TextEditor(text: $item).frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.6)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary).opacity(0.75))
                            .focused($isFieldFocused)
                            .offset(x: -20)
                    
                    }
                .contentShape(Rectangle())
                    .onTapGesture {
                        self.isFieldFocused = false
                    }
                .onChange(of: self.item) {
                    newItem in
                    self.inputStrings[self.id] = self.item
                }.onAppear(perform: {
                    self.item = self.inputStrings[self.id]!
                }).onDisappear(perform: {
                    self.justAdded = false
                })
            }
        }
    
    static func ==(lhs: SingleInputBoxView, rhs: SingleInputBoxView) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.item)
    }
}
