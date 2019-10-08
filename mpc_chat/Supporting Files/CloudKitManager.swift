//
//  CloudKitManager.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/23/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitManager {
    class func isUserLoggedIntoICloud(completion: @escaping (_ error: Error?)-> Void) {
        
        CKContainer.default().accountStatus(completionHandler: {
            (accountStatus, error) -> Void in
            
            switch accountStatus {
            case .available:
                completion(nil)
            case .restricted:
                completion(error)
            default:
                
                completion(NSError(domain: "force pop up screen", code: 458, userInfo: nil))
                
            }
            
        })
    }
}
