//
//  MPCChatUtility.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/27/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation

class MPCChatUtility {
    
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

