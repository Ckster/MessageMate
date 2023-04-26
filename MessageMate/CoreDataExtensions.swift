//
//  CoreDataExtensions.swift
//  Interactify
//
//  Created by Erick Verleye on 4/24/23.
//

import Foundation
import CoreData

extension MetaUser {
    func getProfilePicture(page: MetaPage) {
        if self.metaPage != nil && page.accessToken != nil {
            let urlString = "https://graph.facebook.com/v16.0/\(self.id!)?access_token=\(page.accessToken!)"
            
            completionGetRequest(urlString: urlString) {
                profileData in
                print("PROFILE DATA", profileData)
                let profilePicURL = profileData["profile_pic"] as? String
                print(profilePicURL)
                self.profilePictureURL = URL(string: profilePicURL?.replacingOccurrences(of: "\\", with: "") ?? "")
            }
        }
        else {
            print("META PAGE IS NIL \(page) \(page.accessToken)")
        }
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
}
