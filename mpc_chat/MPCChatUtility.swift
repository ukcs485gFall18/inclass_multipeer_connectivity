//
//  MPCChatUtility.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/27/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import UIKit

class MPCChatUtility {
    
    class func getmyUserUUID()->String?{
        var returnUUID:String!
        
        if (UserDefaults.standard.object(forKey: kAdvertisingUUID) == nil){
            //Create new UUID
            returnUUID = UUID.init().uuidString
            UserDefaults.standard.setValue(returnUUID, forKey: kAdvertisingUUID)
            UserDefaults.standard.synchronize()
            
            print("Generated new UUID: \(returnUUID!) and saved to user defaults")
        }else{
            //Get the data available
            guard let uuid = UserDefaults.standard.value(forKey: kAdvertisingUUID) as? String else{
                print("Error in MPCChatUtility.getmyUserUUID(), could not get String from user defaults")
                return nil
            }
            
            returnUUID = uuid
            print("Found UUID: \(returnUUID!) in user defaults")
        }
        
        return returnUUID
    }
    
    class func buildAdvertisingDictionary()->[String:String]?{
        guard let uuid = MPCChatUtility.getmyUserUUID() else{
            return nil
        }
        
        return [kAdvertisingUUID: uuid]
    }
    
    class func getCurrentTime() -> Date {
        return Date()
    }
    
    class func convertDateToString(date: Date) -> String{
        
        let dataFormatter:DateFormatter = DateFormatter()
        dataFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dataFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        return dataFormatter.string(from: date)
    }
}

// Got this code from: https://stackoverflow.com/questions/24126678/close-ios-keyboard-by-touching-anywhere-using-swift
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
