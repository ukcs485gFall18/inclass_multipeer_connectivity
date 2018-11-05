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
    
    class func getRelativeTime(_ timeStamp: Date) -> String {
        
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(([NSCalendar.Unit.year, NSCalendar.Unit.month, NSCalendar.Unit.day, NSCalendar.Unit.hour, NSCalendar.Unit.minute]), from: timeStamp)
        
        let date = (Calendar.current as NSCalendar).date(era: 1, year: components.year!, month: components.month!, day: components.day!, hour: components.hour!, minute: components.minute!, second: 0, nanosecond: 0)
        
        return date!.relativeTime
    }
    
    class func convertDateToString(date: Date) -> String{
        
        let dataFormatter:DateFormatter = DateFormatter()
        dataFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dataFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        
        return dataFormatter.string(from: date)
    }
}

// Source: https://stackoverflow.com/questions/24126678/close-ios-keyboard-by-touching-anywhere-using-swift
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

//Source: Leo Dabus, http://stackoverflow.com/questions/27310883/swift-ios-doesrelativedateformatting-have-different-values-besides-today-and
extension Date {
    func yearsFrom(_ date:Date)   -> Int {
        return (Calendar.current as NSCalendar).components(.year, from: date, to: self, options: []).year!
    }
    func monthsFrom(_ date:Date)  -> Int {
        return (Calendar.current as NSCalendar).components(.month, from: date, to: self, options: []).month!
    }
    func weeksFrom(_ date:Date)   -> Int {
        return (Calendar.current as NSCalendar).components(.weekOfYear, from: date, to: self, options: []).weekOfYear!
    }
    func daysFrom(_ date:Date)    -> Int {
        return (Calendar.current as NSCalendar).components(.day, from: date, to: self, options: []).day!
    }
    func hoursFrom(_ date:Date)   -> Int {
        return (Calendar.current as NSCalendar).components(.hour, from: date, to: self, options: []).hour!
    }
    func minutesFrom(_ date:Date) -> Int {
        return (Calendar.current as NSCalendar).components(.minute, from: date, to: self, options: []).minute!
    }
    func secondsFrom(_ date:Date) -> Int {
        return (Calendar.current as NSCalendar).components(.second, from: date, to: self, options: []).second!
    }
    var relativeTime: String {
        let now = Date()
        if now.yearsFrom(self)   > 0 {
            return now.yearsFrom(self).description  + " year"  + { return now.yearsFrom(self)   > 1 ? "s" : "" }() + " ago"
        }
        if now.monthsFrom(self)  > 0 {
            return now.monthsFrom(self).description + " month" + { return now.monthsFrom(self)  > 1 ? "s" : "" }() + " ago"
        }
        if now.weeksFrom(self)   > 0 {
            return now.weeksFrom(self).description  + " week"  + { return now.weeksFrom(self)   > 1 ? "s" : "" }() + " ago"
        }
        if now.daysFrom(self)    > 0 {
            if daysFrom(self) == 1 { return "Yesterday" }
            return now.daysFrom(self).description + " days ago"
        }
        if now.hoursFrom(self)   > 0 {
            return "\(now.hoursFrom(self)) hour"     + { return now.hoursFrom(self)   > 1 ? "s" : "" }() + " ago"
        }
        if now.minutesFrom(self) > 0 {
            return "\(now.minutesFrom(self)) minute" + { return now.minutesFrom(self) > 1 ? "s" : "" }() + " ago"
        }
        if now.secondsFrom(self) > 0 {
            if now.secondsFrom(self) < 15 { return "Just now"  }
            return "\(now.secondsFrom(self)) second" + { return now.secondsFrom(self) > 1 ? "s" : "" }() + " ago"
        }
        return ""
    }
}
