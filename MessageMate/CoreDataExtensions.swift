//
//  CoreDataExtensions.swift
//  Interactify
//
//  Created by Erick Verleye on 4/24/23.
//

import Foundation
import CoreData

extension MetaUser {
    func getProfilePicture(page: MetaPage, completion: @escaping () -> Void) {
        if page.accessToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/\(self.id!)?access_token=\(page.accessToken!)"
            
            completionGetRequest(urlString: urlString) {
                profileData in
                print("PROFILE DATA", profileData, page.accessToken!, self.id)
                let profilePicURL = profileData["profile_pic"] as? String
                if profilePicURL != nil {
                    let url = URL(string: profilePicURL!)
                    if url != nil {
                        self.profilePictureURL = url!
                    }
                }
                completion()
            }
        }
        else {
            completion()
            print("META PAGE IS NIL \(page) \(page.accessToken)")
        }
    }
    
    
    func displayName() -> String {
        return self.name ?? self.username ?? self.email ?? ""
    }
    
}


extension MetaPage {
    func getProfilePicture() async {
        let urlString = "https://graph.facebook.com/v16.0/\(self.id!)/picture?redirect=0"

        let profileData = await getRequest(urlString: urlString)
        if profileData != nil {
            let data = profileData!["data"] as? [String: AnyObject]
            if data != nil {
                let profilePicURL = data!["url"] as? String
                self.photoURL = URL(string: profilePicURL?.replacingOccurrences(of: "\\", with: "") ?? "")
            }
        }
    }

    func getPageBusinessAccountId() async {
        let urlString = "https://graph.facebook.com/v16.0/\(self.id!)?fields=instagram_business_account&access_token=\(self.accessToken!)"

        let responseData: (HTTPURLResponse?, Data?)? = await getRequestResponse(urlString: urlString)
        var returnId: String? = nil
        if responseData != nil {
            let header = responseData!.0
            let data = responseData!.1

            if header != nil {
                // First look in the use case header field
                let headerJson = header!.allHeaderFields[AnyHashable("x-business-use-case-usage")] as? String
                if headerJson != nil {
                    let businessUseCase = convertToDictionary(text: headerJson!)
                    if businessUseCase != nil {
                        for accountId in businessUseCase!.keys {
                            let valueDict = businessUseCase![accountId] as? [[String: Any]]
                            if valueDict != nil {
                                let typeDict = valueDict!.first
                                if typeDict != nil {
                                    let type = typeDict!["type"] as? String
                                    if type != nil && type == "instagram" {
                                        returnId = accountId
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Otherwise look in the response data. This should only contain the business account ID for admin pages, because it is not a business use case then
            else {
                if data != nil {
                    do {
                        if let jsonDataDict = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: AnyObject] {
                            let instaData = jsonDataDict["instagram_business_account"] as? [String: String]
                            if instaData != nil {
                                let id = instaData!["id"]
                                if id != nil {
                                    returnId = id!
                                }
                            }
                        }
                    }
                    catch {

                    }

                }
            }
        }
        self.businessAccountID = returnId
    }
}

extension Conversation {
    func updateCorrespondent() -> [MetaUser] {
        var rList: [MetaUser] = []
        if let messages = self.messages as? Set<Message> {
            let conversationMessages = Array(messages)
            for message in conversationMessages {
                if message.from != nil && message.to != nil {
                    if message.from!.id != (self.platform == "instagram" ? self.metaPage!.businessAccountID : self.metaPage!.id)
                    {
                        print("A")
                        self.correspondent = message.from
                        rList = [message.from!, message.to!]
                        break
                    }
                    else {
                        print("B")
                        self.correspondent = message.to
                        rList = [message.to!, message.from!]
                        break
                    }
                }
                else {
                    print("C corr")
                }
                
            }
            
            if conversationMessages.count == 0 {
                print("B corr")
            }
            
        }
        else {
            print("A corr")
        }
        
        return rList
    }
    
//    public override func validateForInsert() throws {
//            try super.validateForInsert()
//
//            let context = self.managedObjectContext!
//            let request = NSFetchRequest<Conversation>(entityName: "Conversation")
//            request.predicate = NSPredicate(format: "id == %@", self.id!)
//            let count = try context.count(for: request)
//
//            if count > 0 {
//                throw NSError(domain: "erickverleye.MessageMate", code: 0, userInfo: [
//                    NSLocalizedDescriptionKey: "Cannot insert. A conversation with this id already exists."
//                ])
//            }
//        }

//    public override func validateForUpdate() throws {
//            try super.validateForUpdate()
//
//            let context = self.managedObjectContext!
//            let request = NSFetchRequest<Conversation>(entityName: "Conversation")
//            request.predicate = NSPredicate(format: "id == %@ AND self != %@", self.id!, self)
//            let count = try context.count(for: request)
//
//            if count > 0 {
//                throw NSError(domain: "erickverleye.MessageMate", code: 0, userInfo: [
//                    NSLocalizedDescriptionKey: "A conversation with this id already exists."
//                ])
//            }
//        }
}


extension Message {
    
//    public override func validateForInsert() throws {
//            try super.validateForInsert()
//
//            let context = self.managedObjectContext!
//            let request = NSFetchRequest<Message>(entityName: "Message")
//            request.predicate = NSPredicate(format: "id == %@", self.id!)
//            let count = try context.count(for: request)
//
//            if count > 0 {
//                throw NSError(domain: "erickverleye.MessageMate", code: 0, userInfo: [
//                    NSLocalizedDescriptionKey: "A message with this id already exists."
//                ])
//            }
//        }
//
//    public override func validateForUpdate() throws {
//            try super.validateForUpdate()
//
//            let context = self.managedObjectContext!
//            let request = NSFetchRequest<Message>(entityName: "Message")
//            request.predicate = NSPredicate(format: "id == %@ AND self != %@", self.id!, self)
//            let count = try context.count(for: request)
//
//            if count > 0 {
//                throw NSError(domain: "erickverleye.MessageMate", code: 0, userInfo: [
//                    NSLocalizedDescriptionKey: "A message with this id already exists."
//                ])
//            }
//        }
    
    
}
