//
//  SessionStore.swift
//  MessageMate
//
//  Created by Erick Verleye on 1/21/23.
//
import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseMessaging
import FBSDKLoginKit
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

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
    @Published var availablePages: [MetaPage] = []
    @Published var loadingFacebookUserToken: Bool = true
    
    // This is sort of abusive
    @Published var videoPlayerUrl: URL?
    @Published var fullScreenImageUrlString: String?
    
    // TODO: Add in actual workflow to make this false when it needs to be
    @Published var onboardingCompleted: Bool? = nil
    
    @Published var unreadMessages: Int = 0
    
    private var db = Firestore.firestore()
    let loginManager = LoginManager()
    
    override init() {
        super.init()
        
        // Check to see if the user is authenticated
        if self.user.user != nil {
            
            // See if the user has completed the onboarding
            self.getOnboardingStatus()
            
            // See if the user's document is in the database
            if self.user.uid != nil {
                self.db.collection(Users.name).document(self.user.uid!).getDocument(
                    completion: {
                        data, error in
                        print("READ J")
                        if error == nil && data != nil {
                            self.getFacebookUserToken()
                            self.isLoggedIn = .signedIn
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
    
    func updateAvailablePages() async {
        if self.facebookUserToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/me/accounts?access_token=\(self.facebookUserToken!)"
            
            let jsonDataDict = await getRequest(urlString: urlString)
            if jsonDataDict != nil {
                let pages = jsonDataDict!["data"] as? [[String: AnyObject]]
                if pages != nil {
                    var newPages: [MetaPage] = []
                    let pageCount = pages!.count
                    var pageIndex = 0
                    
                    for page in pages! {
                        pageIndex = pageIndex + 1
                        let pageAccessToken = page["access_token"] as? String
                        let category = page["category"] as? String
                        let name = page["name"] as? String
                        let id = page["id"] as? String
                        
                        if pageAccessToken != nil && category != nil && name != nil && id != nil {
                            let newPage = MetaPage(id: id!, name: name!, accessToken: pageAccessToken!, category: category!)
                            await newPage.getPageBusinessAccountId(page: newPage)
                            await newPage.getProfilePicture(accountId: id!)
                            
                            newPages.append(newPage)
                            initializePage(page: newPage)
                            if pageIndex == pageCount {
                                self.availablePages = newPages.sorted {$0.name.first! < $1.name.first!}
                            }
                        }
                    }
                }
            }
        }
    }
    
    func updateSelectedPage() {
        if (self.selectedPage == nil || !self.availablePages.contains(self.selectedPage!)) && self.availablePages.count > 0 {
            self.selectedPage = self.availablePages[0]
        }
    }
    
    func getFacebookUserToken() {
        if self.user.uid != nil {
            self.db.collection(Users.name).document(self.user.uid!).getDocument(completion:  {
                data, error in
                guard let data = data?.data() else {
                    self.loadingFacebookUserToken = false
                    return
                }
                self.facebookUserToken = data[Users.fields.FACEBOOK_USER_TOKEN] as? String
                self.loadingFacebookUserToken = false
            })
        }
        else {
            self.loadingFacebookUserToken = false
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
                var completedPages = 0
                print(self.availablePages)
                for page in self.availablePages {
                    self.db.collection(Pages.name).document(page.id).updateData([Pages.fields.APNS_TOKENS: FieldValue.arrayRemove([Messaging.messaging().fcmToken ?? ""])], completion: {
                        error in
                        print("A", error)
                        completedPages = completedPages + 1
                        if completedPages == self.availablePages.count {
                            self.deAuth()
                        }
                    })
                }
                if self.availablePages.count == 0 {
                    self.deAuth()
                }
            }
        })
    }
    
    func deAuth() {
        do {
            try Auth.auth().signOut()
            self.loginManager.logOut()
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
    
//    func facebookLogin(authWorkflow: Bool) {
//        let permissions = authWorkflow ? [] : []
//        self.loginManager.logIn(permissions: [], from: nil) { (loginResult, error) in
//            self.signInError = error?.localizedDescription ?? ""
//            if error == nil {
//                if loginResult?.isCancelled == false {
//                    let credential = FacebookAuthProvider.credential(withAccessToken: AccessToken.current!.tokenString)
//                    print(AccessToken.current!.tokenString)
//                    if authWorkflow {
//                        self.firebaseAuthWorkflow(credential: credential)
//                    }
//                }
//            }
//            else {
//                print(error)
//                // There was an error signing in
//            }
//        }
//    }
    
    func facebookLogin(authWorkflow: Bool) {
        let loginManager = LoginManager()
        
        // TODO: Try to make this a database record that is somehow accesible
        loginManager.logIn(permissions: [
            "instagram_manage_messages",
            "pages_manage_metadata",
            "pages_read_engagement",
            "pages_messaging"
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
    
    
//    func googleLogin(authWorkflow: Bool) {
//        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
//
//        // Create Google Sign In configuration object.
//        let config = GIDConfiguration(clientID: clientID)
//
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
//        guard let rootViewController = windowScene.windows.first?.rootViewController else { return }
//
//        // Start the sign in flow!
//        GIDSignIn.sharedInstance.signIn(with: config, presenting: rootViewController) { [unowned self] user, error in
//
//          if let error = error {
//              self.signInError = error.localizedDescription
//              return
//          }
//
//          guard
//            let authentication = user?.authentication,
//            let idToken = authentication.idToken
//          else {
//              return
//          }
//            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: authentication.accessToken)
//            if authWorkflow {
//                firebaseAuthWorkflow(credential: credential)
//            }
//          return
//        }
//    }
        
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
                        self.isLoggedIn = .signedIn
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
                        self.isLoggedIn = .signedIn
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
