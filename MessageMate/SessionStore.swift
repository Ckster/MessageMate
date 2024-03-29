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

let conversationDayLimit = 90

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
    @Published var activePageIDs: [String] = []
    
    @Published var videoPlayerUrl: URL?
    @Published var fullScreenImageData: Data?
    
    @Published var autoGeneratingMessage: Bool = false
    
    @Published var onboardingCompleted: Bool? = nil
    @Published var initializingPageOnOnboarding: Bool? = nil
    
    @Published var unreadMessages: Int = 0
    @Published var conversationsToUpdateByPage: [String: Int] = [:]
    
    let context: NSManagedObjectContext
    private var db = Firestore.firestore()
    let loginManager = LoginManager()
    
    init(context: NSManagedObjectContext) {
        self.context = context
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
                            
//                            if self.onboardingCompleted == true && self.facebookUserToken != nil {
//                                self.getPageInfo() {}
//                            }
                            
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
            self.db.collection("\(Pages.name)/\(page.id)/\(Pages.collections.BUSINESS_INFO.name)").document(Pages.collections.BUSINESS_INFO.documents.FIELDS.name).getDocument(completion:  {
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
        let currentUserPages = self.fetchCurrentUserPages()
        
        if currentUserPages == nil {
            // TODO: Tell user there was an error signing out
            return
        }
        
        self.db.collection(Users.name).document(self.user.uid ?? "").updateData(
            [
                Users.fields.TOKENS: FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""]),
                Users.fields.FACEBOOK_USER_TOKEN: nil
            ], completion: {
                error in
                print(error)
                if error == nil {
                    DispatchQueue.main.async {
                        var completedPages = 0
                        for page in currentUserPages! {
                            self.db.collection(Pages.name).document(page.id).updateData([Pages.fields.APNS_TOKENS: FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""])], completion: {
                                error in
                                print("A", error)
                                completedPages = completedPages + 1
                                if completedPages == currentUserPages!.count {
                                    self.onboardingCompleted = nil
                                    self.deAuth()
                                }
                            })
                        }
                        if currentUserPages!.count == 0 {
                            self.deAuth()
                        }
                    }
                }
            }
        )
    }
    
    func deAuth() {
        do {
            try Auth.auth().signOut()
            self.loginManager.logOut()
            self.facebookUserToken = nil
            self.selectedPage = nil
            
            self.isLoggedIn = .signedOut
            // GIDSignIn.sharedInstance().signOut()
            UIApplication.shared.unregisterForRemoteNotifications()
        }
        catch {
            self.db.collection(Users.name).document(self.user.uid ?? "").updateData([Users.fields.TOKENS: FieldValue.arrayUnion([Messaging.messaging().fcmToken ?? ""])])
            self.isLoggedIn = .signedIn
            // self.loginManager.logIn()
        }
    }
    
    func fetchCurrentUserPages() -> [MetaPage]? {
        if let id = self.user.uid {
            let fetchRequest: NSFetchRequest<MetaPage> = MetaPage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "firebaseUser.id == %@", id)
            do {
                let pages = try self.context.fetch(fetchRequest)
                return pages
            } catch {
                print("Error fetching user: \(error.localizedDescription)")
                return nil
            }
        }
        else {
            return nil
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
                    if authWorkflow {
                        let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)
                        self.firebaseAuthWorkflow(credential: credential) {
                            self.uploadFBToken(userAccessToken: userAccessToken)
                            self.facebookUserToken = userAccessToken
                        }
                    }
                    else {
                        self.uploadFBToken(userAccessToken: userAccessToken)
                        self.facebookUserToken = userAccessToken
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
            print("AUth state changed")
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
