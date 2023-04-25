//
//  SessionStore.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//
import SwiftUI
import Firebase
//import GoogleSignIn
import FirebaseMessaging
import FBSDKLoginKit
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import CoreData

import Combine

enum SignInState {
    case signedIn
    case signedOut
    case loading
  }


class PushNotificationState: ObservableObject {
    static let shared = PushNotificationState()
    @Published var conversationToNavigateTo : String?
}


class TabSelectionState: ObservableObject {
    static let shared = TabSelectionState()
    @Published var selectedTab : Int = 2
}

let conversationDayLimit = 2

/**
 Creates an instance of the users authentication state and other single instance attributes for the user's session
    - Parameters:
        -hadle: Connection to the user's auth state
        -user: User object containing information about the current user
        -signUpError: Text for any sign up errors that need to be displayed to the user
        -signInError: Text for any sign in error that need to be displayed to the user
        -isLoggedIn: The sign in state of the user
        -isTutorialCompleted: True if the user has completed the tutorial already
        -db: Connection to Firestore
 */
class SessionStore : NSObject, ObservableObject {
    var handle: AuthStateDidChangeListenerHandle?
    @ObservedObject var user: User = User()
    @Published var signUpError: String = ""
    @Published var signInError: String = ""
    @Published var isLoggedIn: SignInState = .loading
    @Published var showMenu: Bool = true
    @Published var facebookUserToken: String? = nil
    @Published var selectedPage: MetaPage?
    @Published var loadingFacebookUserToken: Bool = true
    @Published var loadingPageInformation: Bool = true
    @Published var webhooksSubscribed: Bool?
    @Published var activePages: [MetaPage] = []
    // This is sort of abusive
    @Published var videoPlayerUrl: URL?
    @Published var fullScreenImageUrlString: String?
    @Published var autoGeneratingMessage: Bool = false
    
    // TODO: Add in actual workflow to make this false when it needs to be
    @Published var onboardingCompleted: Bool? = nil
    
    @Published var unreadMessages: Int = 0
    
    private var db = Firestore.firestore()
    let loginManager = LoginManager()
    
//    @Environment(\.managedObjectContext) var moc
//
//    override init() {
//        super.init()
//        self.initWorkflow()
//    }
    
    let moc: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.moc = context
        super.init()
        self.initWorkflow()
    }
    
    func initWorkflow() {
        // Check to see if the user is authenticated
        if self.$user.user != nil {
            // See if the user's document is in the database
            if self.user.uid != nil {
                self.db.collection(Users.name).document(self.user.uid!).getDocument(
                    completion: {
                        data, error in
                        print("READ J")
                        if error == nil && data != nil {
                            self.onboardingCompleted = data![Users.fields.ONBOARDING_COMPLETED] as? Bool
                            self.facebookUserToken = data![Users.fields.FACEBOOK_USER_TOKEN] as? String
                            self.loadingFacebookUserToken = false
                            
                            DispatchQueue.main.async {
                                self.isLoggedIn = .signedIn
                            }
                            
                            if self.onboardingCompleted == true && self.facebookUserToken != nil {
                                self.getPageInfo() {}
                            }
                            
                        }
                        else {
                            // For some reason the users UID could not be resolved
                            do {
                                try Auth.auth().signOut()
                                self.isLoggedIn = .signedOut
                            }
                            catch {
                                // Don't do anything, there was no user
                            }
                        }
                    }
                )
            }
            
            // For some reason the users UID could not be resolved
            else {
                do {
                    try Auth.auth().signOut()
                    self.isLoggedIn = .signedOut
                }
                catch {
                    // Don't do anything, there was no user
                }
            }
        }
        
        // The user is not authenticated
        else {
            self.isLoggedIn = .signedOut
        }
    }
    
    func getPageInfo(completion: @escaping () -> Void) {
        Task {
            self.loadingPageInformation = true
            print("Starting B")
            // Get the Business Pages associated with the account
            await self.updateActivePages()
            
            // Update the conversations for each page. When this is done the screen will stop loading
            await self.updatePages() {
                print("Done updating pages")
                completion()
                self.refreshProfilePictureURLs()
            }
        }
    }
    
    func fetchUsers() -> [MetaUser] {
            let request: NSFetchRequest<MetaUser> = MetaUser.fetchRequest()
            request.sortDescriptors = []

            do {
                let users = try self.moc.fetch(request)
                return users
            } catch {
                // handle error
                print("Error fetching messages: \(error.localizedDescription)")
                return []
            }
        }
    
    func refreshProfilePictureURLs() {
        let existingUsers = self.fetchUsers()
        
        // Start of the async get of profile pic url
        for user in existingUsers {
            user.getProfilePicture()
            // Might need to save here
        }
    }
    
    func getOnboardingStatus() {
        /// Reads whether the user has completed the tutorial, and udpates the observable object in the session
        
        if self.user.uid != nil {
            Firestore.firestore().collection(Users.name).document(self.user.uid!).getDocument(
                completion: { data, error in
                    
                    print("READ K")
                    guard let data = data?.data() else {
                        
                        // Could not read the data, so just show the user the tutorial
                        self.onboardingCompleted = false
                        return
                    }
                    
                    if data[Users.fields.ONBOARDING_COMPLETED] != nil {
                        self.onboardingCompleted = data[Users.fields.ONBOARDING_COMPLETED] as? Bool ?? false
                    }
                    else {
                        // Could not read the data or it wasn't there. Show the user the tutorial
                        self.onboardingCompleted = false
                    }
                }
            )
        }
        
        else {
            self.onboardingCompleted = false
        }
    }
    
    func updateActivePages() async {
        if self.facebookUserToken != nil {
            @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
            
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.facebookUserToken!)"
            
            let jsonDataDict = await getRequest(urlString: urlString)
            var newActivePages: [MetaPage] = []
            if jsonDataDict != nil {
                let pages = jsonDataDict!["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var activeIDs: [String] = []
                    let pageCount = pages!.count
                    var pageIndex = 0
                    
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if id != nil {
                            activeIDs.append(id!)
                            let existingPage = existingPages.first(where: { $0.id == id! })
                            
                            // Update some fields
                            if existingPage != nil {
                                existingPage!.category = category
                                existingPage!.name = name
                                existingPage!.accessToken = pageAccessToken
                                existingPage!.active = true
                                await existingPage!.getPageBusinessAccountId()
                                await existingPage!.getProfilePicture()
                                newActivePages.append(existingPage!)
                            }
                            
                            // Create a new MetaPage instance
                            else {
                                let newPage = MetaPage(context: self.moc)
                                newPage.uid = UUID()
                                newPage.id = id
                                newPage.category = category
                                newPage.name = name
                                newPage.accessToken = pageAccessToken
                                newPage.active = true
                                initializePage(page: newPage)
                                await newPage.getPageBusinessAccountId()
                                await newPage.getProfilePicture()
                                newActivePages.append(newPage)
                            }
                        }
                        
                        if pageIndex == pageCount {
                            // Deactive any pages that were not in response
                            for page in existingPages.lazy {
                                if page.id != nil {
                                    if !activeIDs.contains(page.id!) {
                                        page.active = false
                                    }
                                }
                                else {
                                    page.active  = false
                                }
                            }
                            
                            // Save the changes
                            self.activePages = newActivePages
                            print(self.activePages)
                            print("Saving active pages")
                            try? self.moc.save()
                        }
                    }
                }
            }
        }
    }
    
    func updateSelectedPage() {
        @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
        if self.selectedPage == nil {
            // Find the default if there is one
            let defaultPage: MetaPage? = existingPages.first(where: {$0.active && $0.isDefault})
            
            // If not set the default to the first active page
            if defaultPage == nil {
                let newDefault = existingPages.first(where: {$0.active})
                if newDefault != nil {
                    newDefault!.isDefault = true
                    self.selectedPage = newDefault!
                    self.subscribeToWebhooks(page: newDefault!) {}
                }
                else {
                    // There are no active pages ...
                }
            }
            
            // If so then set the selected page to it
            else {
                self.selectedPage = defaultPage!
                self.subscribeToWebhooks(page: defaultPage!) {}
            }
            
        }
        else {
            // First check if the currently selected page is in the set of activated pages and if it is the default. If not switch to defualt if there is one; if not pick the first page and set it to the default
            let existingActivePage: MetaPage? = existingPages.first(where: {$0.active && $0.id == self.selectedPage!.id})
            
            if existingActivePage != nil {
                // Just double check on webhooks
                self.subscribeToWebhooks(page: self.selectedPage!) {}
            }
            
            else {
                // See if there is a default
                let defaultPage: MetaPage? = existingPages.first(where: {$0.active && $0.isDefault})
                
                // Set it if there is one and check webhooks
                if defaultPage != nil {
                    self.selectedPage = defaultPage!
                    self.subscribeToWebhooks(page: defaultPage!) {}
                }
                
                // If not then find first active page to set a new default
                let newDefault = existingPages.first(where: {$0.active})
                if newDefault != nil {
                    newDefault!.isDefault = true
                    self.selectedPage = newDefault!
                    self.subscribeToWebhooks(page: newDefault!) {}
                }
                else {
                    // There are no active pages ...
                }
            }
        }
        
        try? self.moc.save()
        
    }
    
    func getFacebookUserToken(completion: @escaping () -> Void) {
        if self.user.uid != nil {
            self.db.collection(Users.name).document(self.user.uid!).getDocument(completion:  {
                data, error in
                if data != nil && error == nil {
                    self.facebookUserToken = data![Users.fields.FACEBOOK_USER_TOKEN] as? String
                    self.loadingFacebookUserToken = false
                    completion()
                }
                else {
                    self.loadingFacebookUserToken = false
                    completion()
                }
            })
        }
        else {
            self.loadingFacebookUserToken = false
            completion()
        }
    }
    
    func getMissingRequiredFields(page: MetaPage, completion: @escaping ([String]) -> Void) {
        let requiredFields = [
            Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.BUSINESS_NAME,
            //            Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.INDUSTRY,
            //            Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_NAME,
            //            Pages.collections.BUSINESS_INFO.documents.FIELDS.fields.SENDER_CHARACTERISTICS
        ]
        if page.id != nil {
            self.db.collection("\(Pages.name)/\(page.id!)/\(Pages.collections.BUSINESS_INFO.name)").document(Pages.collections.BUSINESS_INFO.documents.FIELDS.name).getDocument(completion:  {
                data, error in
                if data != nil && error == nil {
                    var missingRequiredFields: [String] = []
                    for field in requiredFields {
                        let value = data![field] as? String
                        if value == nil || value == "" {
                            missingRequiredFields.append(field)
                        }
                    }
                    completion(missingRequiredFields)
                }
                else {
                    completion(requiredFields)
                }
            })
        }
        else {
            completion([])
        }
    }
    
    func signOut () {
        // TODO: Remove FB user token
        self.db.collection(Users.name).document(self.user.user!.uid).updateData(
            [
                Users.fields.TOKENS: FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""]),
                Users.fields.FACEBOOK_USER_TOKEN: nil
            ], completion: {
                error in
                print(error)
                if error == nil {
                    @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
                    let activePages = existingPages.filter {$0.active && $0.id != nil}
                    var completedPages = 0
                    for page in activePages {
                        self.db.collection(Pages.name).document(page.id!).updateData([Pages.fields.APNS_TOKENS: FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""])], completion: {
                            error in
                            print("A", error)
                            completedPages = completedPages + 1
                            if completedPages == activePages.count {
                                self.onboardingCompleted = nil
                                self.deAuth()
                            }
                        })
                    }
                    if activePages.count == 0 {
                        self.deAuth()
                    }
                }
            })
    }
    
    func deAuth() {
        do {
            try Auth.auth().signOut()
            self.loginManager.logOut()
            self.facebookUserToken = nil
            self.selectedPage = nil
            
            // Delete all of the data for this user from CoreData
            @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
            let activePages = existingPages.filter {$0.active}
            for page in activePages {
                page.active = false
            }
            self.isLoggedIn = .signedOut
            // GIDSignIn.sharedInstance().signOut()
            UIApplication.shared.unregisterForRemoteNotifications()
        }
        catch {
            self.db.collection(Users.name).document(self.user.user!.uid).updateData([Users.fields.TOKENS: FieldValue.arrayUnion([Messaging.messaging().fcmToken ?? ""])])
            self.isLoggedIn = .signedIn
            // self.loginManager.logIn()
        }
    }
    
    func facebookLogin(authWorkflow: Bool) {
        // TODO: Store user tokens in CoreData
        let loginManager = LoginManager()
        
        // TODO: Try to make this a database record that is somehow accesible
        loginManager.logIn(permissions: [
            "instagram_manage_messages",
            "pages_manage_metadata",
            "pages_read_engagement",
            "pages_messaging",
            "pages_show_list",
            "pages_read_engagement"
        ], from: nil) { (loginResult, error) in
            self.signInError = error?.localizedDescription ?? ""
            if error == nil {
                if loginResult?.isCancelled == false {
                    let userAccessToken = AccessToken.current!.tokenString
                    self.facebookUserToken = userAccessToken
                    
                    if authWorkflow {
                        let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)
                        self.firebaseAuthWorkflow(credential: credential) {
                            self.uploadFBToken(userAccessToken: userAccessToken)
                        }
                    }
                    else {
                        self.uploadFBToken(userAccessToken: userAccessToken)
                    }
                }
            }
            else {
                print("ERROR")
                print(error)
                // TODO: There was an error signing in, show something to the user
            }
        }
    }
    
    func uploadFBToken(userAccessToken: String) {
        // Add to the database
        if self.user.uid != nil {
            self.db.collection(Users.name).document(self.user.uid!).updateData([Users.fields.FACEBOOK_USER_TOKEN: userAccessToken])
        }
    }
    
    func firebaseAuthWorkflow(credential: FirebaseAuth.AuthCredential, completion: @escaping () -> Void) {
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if error == nil && authResult != nil {
                UIApplication.shared.registerForRemoteNotifications()
                self.signInError = error?.localizedDescription ?? ""
                let user = authResult!.user
                let docRef = self.db.collection(Users.name).document(user.uid)
                docRef.getDocument { (document, docError) in
                    print("READ N")
                    
                    // User already exists
                    if let document = document, document.exists {
                        // Show the user the home screen
                        self.initWorkflow()
                        self.addToken()
                        completion()
                    }
                    
                    // User's settings need to be initialized in the Firebase
                    else {
                        let userSettings = self.db.collection(Users.name).document(String(user.uid))
                        
                        // Update session to show tutorial completed is false
                        self.onboardingCompleted = false
                        
                        // Set the initial datafields
                        userSettings.setData([
                            // TODO: Get first name of user from the credential here or earlier on in the auth workflow and put it in the database here
                            Users.fields.ONBOARDING_COMPLETED: false,
                            Users.fields.LEGAL_AGREEMENT: Timestamp.init(),
                            Users.fields.TOKENS: [Messaging.messaging().fcmToken ?? ""]
                        ])
                        
                        // Finally, show the user the home screen
                        self.initWorkflow()
                        completion()
                    }
                }
            }
            else {
                completion()
            }
        }
    }
    
    func unbind () {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    deinit {
        unbind()
    }
    
    func addToken() {
        let token = Messaging.messaging().fcmToken ?? ""
        if token != "" && self.isLoggedIn == .signedIn && self.user.uid != nil {
            self.db.collection(Users.name).document(String(self.user.uid!)).updateData([Users.fields.TOKENS: FieldValue.arrayUnion([token])])
        }
    }
    
    // Messaging functions
    func updatePages(completion: @escaping () -> Void) async {
        self.loadingPageInformation = true
        var pagesLoaded = 0
        
        @FetchRequest(sortDescriptors: []) var existingPages: FetchedResults<MetaPage>
        let activePages = existingPages.filter {$0.active && $0.id != nil}
        
        for page in activePages {
            
            // Update all of the conversations in the database for this page
            for platform in MessagingPlatform.allCases {
                await self.getConversations(page: page, platform: platform)
            }
            
            if let existingConversations = page.conversations! as? Set<Conversation> {
                let conversationsToUpdate = Array(existingConversations).filter {
                    $0.inDayRange &&
                    $0.updatedTime! > $0.lastRefresh ?? Date(timeIntervalSince1970: 0)
                }
                
                for conversation in conversationsToUpdate {
                    print("Getting conversation")
                    self.getNewMessages(page: page, conversation: conversation) {
                        conversationTuple in
                        let newMessages = conversationTuple.0
                        
                        // TODO: Unless there is info on opened status from API I have to assume message has been viewed or we keep some sort of on disk record
                        for message in newMessages {
                            message.opened = true
                        }
                        
                        let pagination = conversationTuple.1
                        
                        if newMessages.count > 0 {
                            let userList = conversation.updateCorrespondent()
                            if userList.count > 0 {
                                page.pageUser = userList[1]
                            }
                        }
                        
                        conversation.messagesInitialized = true
                        
                        var allConversationsLoaded: Bool = true
                        for conversation in conversationsToUpdate {
                            if !conversation.messagesInitialized {
                                allConversationsLoaded = false
                            }
                        }
                        
                        if allConversationsLoaded {
                            
                            // reset for the next reload
                            for conversation in conversationsToUpdate {
                                conversation.messagesInitialized = false
                            }
                            
                            pagesLoaded = pagesLoaded + 1
                            if pagesLoaded == activePages.count {
                                print("All pages loaded")
                                try? self.moc.save()
                                DispatchQueue.main.async {
                                    // Set the selected page is the currently selected page is nil or no longer exists in the set of avaialable pages
                                    self.updateSelectedPage()
                                    self.addConversationListeners(page: self.selectedPage!)
                                    self.loadingPageInformation = false
                                }
                                completion()
                            }
                        }
                    }
                }
                
                // If no conversations mark the page as loaded and see if all pages have been loaded
                if conversationsToUpdate.count == 0 {
                    pagesLoaded = pagesLoaded + 1
                    if pagesLoaded == activePages.count {
                        print("All pages loaded")
                        try? self.moc.save()
                        DispatchQueue.main.async {
                            // Set the selected page is the currently selected page is nil or no longer exists in the set of avaialable pages
                            self.updateSelectedPage()
                            self.addConversationListeners(page: self.selectedPage!)
                            self.loadingPageInformation = false
                        }
                        completion()
                    }
                }
            }
        }
        
        if activePages.count == 0 {
            DispatchQueue.main.async {
                self.loadingPageInformation = false
            }
            completion()
        }
        
    }
    
    func getNewMessages(page: MetaPage, conversation: Conversation, cursor: String? = nil, completion: @escaping (([Message], PagingInfo?)) -> Void) {
        print("Runing getMessages")
        
        if page.accessToken != nil && conversation.id != nil {
            var urlString = "https://graph.facebook.com/v16.0/\(conversation.id!)?fields=messages&access_token=\(page.accessToken!)"
            
            if cursor != nil {
                urlString = urlString + "&after=\(String(describing: cursor))"
            }
            
            if conversation.lastRefresh != nil {
                urlString = urlString + "&since=\(conversation.lastRefresh!.timeIntervalSince1970)"
            }
            
            completionGetRequest(urlString: urlString) {
                jsonDataDict in
                
                let conversationData = jsonDataDict["messages"] as? [String: AnyObject]
                if conversationData != nil {
                    print(conversationData)
                    
                    // Get paging information
                    var pagingInfo: PagingInfo? = nil
                    let pointerData = conversationData!["paging"] as? [String: AnyObject]
                    if pointerData != nil {
                        let cursorData = pointerData!["cursors"] as? [String: String]
                        if cursorData != nil {
                            pagingInfo = PagingInfo(beforeCursor: cursorData!["before"], afterCursor: cursorData!["after"])
                        }
                    }
                    
                    let messageData = conversationData!["data"] as? [[String: AnyObject]]
                    print("Number of messages: \(messageData!.count)")
                    
                    if messageData != nil {
                        let messagesLen = messageData!.count
                        var indexCounter = 0
                        var newMessages: [Message] = []
                        
                        for message in messageData! {
                            let id = message["id"] as? String
                            let createdTime = message["created_time"] as? String
                            
                            if id != nil && createdTime != nil {
                                let messageDataURLString = "https://graph.facebook.com/v16.0/\(id!)?fields=id,created_time,from,to,message,story,attachments,shares&access_token=\(page.accessToken)"
                                
                                completionGetRequest(urlString: messageDataURLString) {
                                    messageDataDict in
                                    if messageDataDict != nil {
                                        var message: Message = Message(context: self.moc)
                                        var appendMessage: Bool = true
                                        switch conversation.platform {
                                        case "instagram":
                                            self.parseInstagramMessage(messageEntity: message, messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!, previousMessage: newMessages.last)
                                        case "facebook":
                                            self.parseFacebookMessage(messageEntity: message, messageDataDict: messageDataDict, message_id: id!, createdTime: createdTime!, previousMessage: newMessages.last)
                                        default:
                                            self.moc.delete(message)
                                            appendMessage = false
                                        }
                                        
                                        message.conversation = conversation
                                        
                                        indexCounter = indexCounter + 1
                                        
                                        if appendMessage {
                                            newMessages.append(message)
                                        }
                                        
                                        if indexCounter == messagesLen {
                                            
                                            newMessages = newMessages.sorted { $0.createdTime! < $1.createdTime! }
                                            var lastDate: Foundation.DateComponents? = nil
                                            for message in newMessages {
                                                let createdTimeDate = Calendar.current.dateComponents([.month, .day], from: message.createdTime!)
                                                var dayStarter = lastDate == nil
                                                if lastDate != nil {
                                                    dayStarter = lastDate!.month! != createdTimeDate.month! || lastDate!.day! != createdTimeDate.day!
                                                }
                                                lastDate = createdTimeDate
                                                message.dayStarter = dayStarter
                                            }
                                            
                                            conversation.lastRefresh = Date()
                                            try? self.moc.save()
                                            completion((newMessages, pagingInfo))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func parseInstagramStoryMention(messageEntity: Message, messageDataDict: [String: Any]) {
        var instagramStoryMention: InstagramStoryMention? = nil
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let mentionData = storyData!["mention"] as? [String: Any]
            if mentionData != nil {
                let id = mentionData!["id"] as? String
                let cdnUrl = mentionData!["link"] as? String
                if cdnUrl != nil {
                    print("updating instagram story")
                    let newInstagramStoryMention = InstagramStoryMention(context: self.moc)
                    newInstagramStoryMention.uid = UUID()
                    newInstagramStoryMention.id = id
                    newInstagramStoryMention.cdnURL = URL(string: cdnUrl!)
                    newInstagramStoryMention.message = messageEntity
                }
            }
        }
    }
    
    func parseInstagramStoryReply(messageEntity: Message, messageDataDict: [String: Any]) {
        var instagramStoryReply: InstagramStoryReply? = nil
        let storyData = messageDataDict["story"] as? [String: Any]
        if storyData != nil {
            print("not nil")
            let replyToData = storyData!["reply_to"] as? [String: Any]
            if replyToData != nil {
                let id = replyToData!["id"] as? String
                let cdnUrl = replyToData!["link"] as? String
                if cdnUrl != nil {
                    print("updating instagram story")
                    let newInstagramStoryReply = InstagramStoryReply(context: self.moc)
                    newInstagramStoryReply.uid = UUID()
                    newInstagramStoryReply.id = id
                    newInstagramStoryReply.cdnURL = URL(string: cdnUrl!)
                    newInstagramStoryReply.message = messageEntity
                }
            }
        }
    }
    
    func parseImageAttachment(messageEntity: Message, messageDataDict: [String: Any]) {
        var imageAttachment: ImageAttachment? = nil
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["image_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            let newImageAttachment = ImageAttachment(context: self.moc)
                            newImageAttachment.uid = UUID()
                            newImageAttachment.url = URL(string: url!)
                            newImageAttachment.message = messageEntity
                        }
                    }
                }
            }
        }
    }
    
    func parseVideoAttachment(messageEntity: Message, messageDataDict: [String: Any]) {
        var imageAttachment: VideoAttachment? = nil
        let attachmentsData = messageDataDict["attachments"] as? [String: Any]
        if attachmentsData != nil {
            let data = attachmentsData!["data"] as? [[String: Any]]
            if data != nil {
                if data!.count > 0 {
                    let image_data = data![0]["video_data"] as? [String: Any]
                    if image_data != nil {
                        let url = image_data!["url"] as? String
                        if url != nil {
                            let newVideoAttachment = VideoAttachment(context: self.moc)
                            newVideoAttachment.uid = UUID()
                            newVideoAttachment.url = URL(string: url!)
                            newVideoAttachment.message = messageEntity
                        }
                    }
                }
            }
        }
    }
    
    func parseInstagramMessage(messageEntity: Message, messageDataDict: [String: Any], message_id: String, createdTime: String, previousMessage: Message? = nil) {
        let fromDict = messageDataDict["from"] as? [String: AnyObject]
        let toDictList = messageDataDict["to"] as? [String: AnyObject]
        let message = messageDataDict["message"] as? String

        if toDictList != nil {
            let toDict = toDictList!["data"] as? [[String: AnyObject]]

            if toDict!.count == 1 {
                if fromDict != nil && toDict != nil && message != nil {
                    let fromUsername = fromDict!["username"] as? String
                    let fromId = fromDict!["id"] as? String
                    let toUsername = toDict![0]["username"] as? String
                    let toId = toDict![0]["id"] as? String
                    
                    parseInstagramStoryMention(messageEntity: messageEntity, messageDataDict: messageDataDict)
                    parseInstagramStoryReply(messageEntity: messageEntity, messageDataDict: messageDataDict)
                    parseImageAttachment(messageEntity: messageEntity, messageDataDict: messageDataDict)
                    parseVideoAttachment(messageEntity: messageEntity, messageDataDict: messageDataDict)

                    if fromUsername != nil && fromId != nil && toUsername != nil && toId != nil {
                        @FetchRequest(sortDescriptors: []) var existingUsers: FetchedResults<MetaUser>
                        
                        let existingFromUser = existingUsers.first(where: {$0.id != fromId!})
                        
                        // Udpdate some thins
                        if existingFromUser != nil {
                            existingFromUser!.username = fromUsername!
                            existingFromUser!.platform = "instagram"
                            messageEntity.from = existingFromUser
                        }
                        
                        else {
                            let newFromUser = MetaUser(context: self.moc)
                            newFromUser.uid = UUID()
                            newFromUser.id = fromId!
                            newFromUser.username = fromUsername!
                            newFromUser.platform = "instagram"
                            messageEntity.from = newFromUser
                        }
                        
                        
                        let existingToUser = existingUsers.first(where: {$0.id != toId!})
                        
                        // Udpdate some thins
                        if existingToUser != nil {
                            existingToUser!.username = toUsername!
                            existingToUser!.platform = "instagram"
                            messageEntity.to = existingToUser
                        }
                        
                        else {
                            let newToUser = MetaUser(context: self.moc)
                            newToUser.uid = UUID()
                            newToUser.id = toId!
                            newToUser.username = toUsername!
                            newToUser.platform = "instagram"
                            messageEntity.to = existingToUser
                        }
                        
                        print("returning message")
                        
                        messageEntity.id = message_id
                        messageEntity.message = message
                        messageEntity.createdTime = Date().facebookStringToDate(fbString: createdTime)
                
                    }
                    else {}
                }
                else {}
            }
            else {}
        }
        else {}
    }
    
    func parseFacebookMessage(messageEntity: Message, messageDataDict: [String: Any], message_id: String, createdTime: String, previousMessage: Message? = nil) {
        let fromDict = messageDataDict["from"] as? [String: AnyObject]
        let toDictList = messageDataDict["to"] as? [String: AnyObject]
        let message = messageDataDict["message"] as? String

        if toDictList != nil {
            let toDict = toDictList!["data"] as? [[String: AnyObject]]
            
            parseImageAttachment(messageEntity: messageEntity, messageDataDict: messageDataDict)

            if toDict!.count == 1 {
                if fromDict != nil && toDict != nil && message != nil {
                    let fromEmail = fromDict!["email"] as? String
                    let fromId = fromDict!["id"] as? String
                    let fromName = fromDict!["name"] as? String
                    
                    let toEmail = toDict![0]["email"] as? String
                    let toName = toDict![0]["name"] as? String
                    let toId = toDict![0]["id"] as? String

                    if fromId != nil && toId != nil {
                        @FetchRequest(sortDescriptors: []) var existingUsers: FetchedResults<MetaUser>
                        
                        let existingFromUser = existingUsers.first(where: {$0.id != fromId!})
                        
                        // Udpdate some thins
                        if existingFromUser != nil {
                            existingFromUser!.name = fromName
                            existingFromUser!.email = fromEmail
                            existingFromUser!.platform = "facebook"
                            messageEntity.from = existingFromUser
                        }
                        
                        else {
                            let newFromUser = MetaUser(context: self.moc)
                            newFromUser.uid = UUID()
                            newFromUser.id = fromId!
                            newFromUser.email = fromEmail
                            newFromUser.name = fromName
                            newFromUser.platform = "facebook"
                            messageEntity.from = newFromUser
                        }
                        
                        
                        let existingToUser = existingUsers.first(where: {$0.id != toId!})
                        
                        if existingToUser != nil {
                            existingToUser!.name = toName
                            existingToUser!.email = toEmail
                            existingToUser!.platform = "facebook"
                            messageEntity.to = existingToUser
                        }
                        
                        else {
                            let newToUser = MetaUser(context: self.moc)
                            newToUser.uid = UUID()
                            newToUser.id = toId!
                            newToUser.email = toEmail
                            newToUser.name = toName
                            newToUser.platform = "facebook"
                            messageEntity.to = newToUser
                        }
                        
                        print("returning message")
                        
                        messageEntity.id = message_id
                        messageEntity.message = message
                        messageEntity.createdTime = Date().facebookStringToDate(fbString: createdTime)
                    }
                    else {}
                }
                else {}
            }
            else {}
        }
        else {}
    }
    
    func getConversations(page: MetaPage, platform: MessagingPlatform) async -> Void {
        var urlString = "https://graph.facebook.com/v16.0/\(page.id)/conversations?"
        
        switch platform {
            case .facebook:
                break
            case .instagram:
                urlString = urlString + "platform=instagram"
        }
        
        urlString = urlString + "&access_token=\(page.accessToken)"
        
        let jsonDataDict = await getRequest(urlString: urlString)
        if jsonDataDict != nil {
            let conversations = jsonDataDict!["data"] as? [[String: AnyObject]]
            if conversations != nil {
                for conversation in conversations! {
                    if page.conversations != nil {
                        let id = conversation["id"] as? String
                        let updatedTime = conversation["updated_time"] as? String
                        
                        if id != nil && updatedTime != nil {
                            if let existingConversations = page.conversations! as? Set<Conversation> {
                                let existingConversation = Array(existingConversations).first(where: {$0.id == id!})
                                
                                let dateUpdated = Date().facebookStringToDate(fbString: updatedTime!)
                                let inDayRange = dateUpdated.distance(to: Date(timeIntervalSince1970: NSDate().timeIntervalSince1970)) < Double(86400 * conversationDayLimit)
                                
                                // Update some fields...
                                if existingConversation != nil {
                                    existingConversation!.updatedTime = dateUpdated
                                    existingConversation!.inDayRange = inDayRange
                                }
                                
                                // Create new instance
                                else {
                                    let newConversation = Conversation(context: self.moc)
                                    newConversation.uid = UUID()
                                    newConversation.metaPage = page
                                    newConversation.id = id!
                                    newConversation.platform = platform == .instagram ? "instagram" : "facebook"
                                    newConversation.updatedTime = dateUpdated
                                    newConversation.inDayRange = inDayRange
                                }
                            }
                        }
                    }
                    else {
                        // TODO:
                    }
                }
            }
            try? self.moc.save()
        }
    }
    
    func initializeConversationCollection(page: MetaPage, completion: @escaping () -> Void) {
        if page.id != nil {
            let conversationsCollection = self.db.collection(Pages.name).document(page.id!).collection(Pages.collections.CONVERSATIONS.name)
            conversationsCollection.getDocuments() {
                docs, error in
                if error == nil && docs != nil {
                    if docs!.isEmpty {
                        conversationsCollection.document("init").setData(["message": nil]) {
                            _ in
                            completion()
                        }
                    }
                    else {
                        completion()
                    }
                }
                else {
                    completion()
                }
            }
        }
    }
    
    func addConversationListeners(page: MetaPage) {
        print("Adding conversation listeners")
        
        self.initializeConversationCollection(page: page) {
            if page.id == nil {
                return
            }
            self.db.collection(Pages.name).document(page.id!).collection(Pages.collections.CONVERSATIONS.name).addSnapshotListener {
                querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for conversations: \(error!)")
                    return
                }

                querySnapshot?.documentChanges.forEach { diff in
                    if (diff.type == .modified || diff.type == .added) {
                        // TODO: Add support for post share and video
                        
                        let data = diff.document.data()
                        let messageText = data["message"] as? String ?? ""
                        let pageId = data["page_id"] as? String
                        let recipientId = data["recipient_id"] as? String
                        let senderId = data["sender_id"] as? String
                        let createdTime = data["created_time"] as? Double
                        let messageId = data["message_id"] as? String
                        let storyMentionUrl = data["story_mention_url"] as? String
                        let imageUrl = data["image_url"] as? String
                        let storyReplyUrl = data["story_reply_url"] as? String
                        let isDeleted = data["is_deleted"] as? Bool
                        
                        if pageId != nil && recipientId != nil && senderId != nil && createdTime != nil && messageId != nil {
                            
                            if page.businessAccountID ?? "" == pageId || page.id! == pageId {
                                var conversationFound: Bool = false
                                
                                if let conversationSet = page.conversations as? Set<Conversation> {
                                    let conversations = Array(conversationSet)
                                    for conversation in conversations {
                                        
                                        // TODO: Having some trouble with this
                                        if conversation.correspondent == nil {
                                            print("Correspondent is nil")
                                        }
                                        
                                        if conversation.correspondent != nil && conversation.correspondent!.id == senderId {
                                            conversationFound = true
                                            let messageDate = Date(timeIntervalSince1970: createdTime! / 1000)
                                            var imageAttachment: ImageAttachment? = nil
                                            var instagramStoryMention: InstagramStoryMention? = nil
                                            var instagramStoryReply: InstagramStoryReply? = nil
                                            
                                            if let messageSet = conversation.messages as? Set<Message> {
                                                let messages = sortMessages(messages: Array(messageSet))
                
                                                if isDeleted != nil && isDeleted! {
                                                    let messageToDelete = messages.first(where: {$0.id == messageId})
                                                    if messageToDelete != nil {
                                                        self.moc.delete(messageToDelete!)
                                                        return
                                                    }
                                                }
                
                                                else {
                                                    let lastDate = Calendar.current.dateComponents([.month, .day], from: messages.last!.createdTime!)
                                                    let messageCompDate = Calendar.current.dateComponents([.month, .day], from: messageDate)
                                                    let dayStarter = lastDate.month! != messageCompDate.month! || lastDate.day! != messageCompDate.day!
                                                    
                                                    let newMessage = Message(context: self.moc)
                                                    newMessage.uid = UUID()
                                                    newMessage.conversation = conversation
                                                    newMessage.message = messageText
                                                    newMessage.to = page.pageUser
                                                    newMessage.from = conversation.correspondent
                                                    newMessage.dayStarter = dayStarter
                                                    newMessage.createdTime = messageDate
                                                    
                                                    if imageUrl != nil {
                                                        let newImageAttachment = ImageAttachment(context: self.moc)
                                                        newImageAttachment.uid = UUID()
                                                        newImageAttachment.url = URL(string: imageUrl!)
                                                        newImageAttachment.message = newMessage
                                                    }
                                                    else {
                                                        if storyMentionUrl != nil {
                                                            // TODO: Get story ID
                                                            let newInstagramStoryMention = InstagramStoryMention(context: self.moc)
                                                            newInstagramStoryMention.uid = UUID()
                                                            newInstagramStoryMention.cdnURL = URL(string: storyMentionUrl!)
                                                            newInstagramStoryMention.id = "1"
                                                            newInstagramStoryMention.message = newMessage
                                                        }
                
                                                        else {
                                                            if storyReplyUrl != nil {
                                                                let newInstagramStoryReply = InstagramStoryReply(context: self.moc)
                                                                newInstagramStoryReply.uid = UUID()
                                                                newInstagramStoryReply.cdnURL = URL(string: storyReplyUrl!)
                                                                newInstagramStoryReply.message = newMessage
                                                                newInstagramStoryReply.id = "1"
                                                            }
                                                        }
                                                    }
                
                                                    if !messages.contains(newMessage)
                                                        && newMessage.createdTime! > messages.last?.createdTime ?? Date(timeIntervalSince1970: .zero)
                                                    {
                                                        print("Updating conversation \(senderId)")
                                                        try? self.moc.save()
                                                        DispatchQueue.main.async {
                                                            self.unreadMessages = self.unreadMessages + 1
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // TODO: Of course facebook doesn't send the conversation ID with the webhook... this should work for now but may be slow. Try to come up with a more efficient way later
                                if !conversationFound && isDeleted != nil && !isDeleted! {
                                    print("Not found", senderId)
                                    Task {
                                        // TODO: Add this back but in another way
                                        await self.updateConversations(page: page)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func updateConversations(page: MetaPage) async {
        for platform in MessagingPlatform.allCases {
            await self.getConversations(page: page, platform: platform)
        }
        
        if let existingConversations = page.conversations! as? Set<Conversation> {
            let conversationsToUpdate = Array(existingConversations).filter {
                $0.inDayRange &&
                $0.updatedTime! > $0.lastRefresh ?? Date(timeIntervalSince1970: 0)
            }
            
            for conversation in conversationsToUpdate {
                self.getNewMessages(page: page, conversation: conversation) {
                    conversationTuple in
                    let messages = conversationTuple.0
                    
                    // TODO: Unless there is info on opened status from API I have to assume message has been viewed or we keep some sort of on disk record
                    for message in messages {
                        message.opened = true
                    }
                    
                    let pagination = conversationTuple.1
                    //conversation.pagination = pagination
                }
            }
        }
    }
    
    func subscribeToWebhooks(page: MetaPage, completion: @escaping () -> Void ) {
        print("SUBSCRIBING")
        // First get a list of registered apps for this page to see if we even need to do this
        let urlString: String = "https://graph.facebook.com/v16.0/\(page.id)/subscribed_apps?access_token=\(page.accessToken)"
        Task {
            let response = await getRequest(urlString: urlString)
            var pageSubscribed = false
            if response != nil {
                print(response!)
                let data = response!["data"] as? [[String: Any]]
                if data != nil {
                    print("SUBSCRIBED GET", data)
                    for app in data! {
                        let appName = app["name"] as? String
                        let subscribedFields = app["subscribed_fields"] as? [String]
                        if appName != nil && subscribedFields != nil {
                            if appName! == "Interactify" && subscribedFields!.contains("messages") {
                                pageSubscribed = true
                            }
                        }
                    }
                }
            }
            
            // POST request to subscription
            if !pageSubscribed {
                let urlString = "https://graph.facebook.com/v16.0/\(page.id)/subscribed_apps"
                let params = ["object": "page",
                              "callback_url": "google.com",
                              "subscribed_fields": "messages",
                              "verify_token": self.facebookUserToken,
                              "access_token": page.accessToken]
                let jsonData = try? JSONSerialization.data(withJSONObject: params)
                if jsonData != nil {
                    postRequestJSON(urlString: urlString, data: jsonData!) {
                        data in
                        if data != nil {
                            print("SUBSCRIBE POST", data)
                            let success = data!["success"] as? Bool
                            if success != nil && success! {
                                print("SUCCESS")
                                pageSubscribed = true
                            }
                        }
                    }
                }
            }
            else {
                pageSubscribed = true
            }
            self.webhooksSubscribed = pageSubscribed
        }
    }
}

/**
 Contains all of the users unique information so that authentication can be checked and the user can configure their settings in firebase
     - Parameters:
        -db: Connection to Firestore
        -uid:User's firebase defined unique identifier
        -user: The firebase User object
 */
class User: ObservableObject {
    @Published var uid: String? = nil
    @Published var user: FirebaseAuth.User? = Auth.auth().currentUser ?? nil
    
    init() {
        self.user?.reload(completion: {error in })
        
        if self.user != nil {
            self.uid = self.user?.uid
        }
        
        else {
            self.user = nil
            self.uid = nil
        }
        
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                self.user = user
                self.uid = user.uid
            }
            
            else {
                self.user = nil
                self.uid = nil
            }
        }
    }
}


//https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.facebookUserToken!)
