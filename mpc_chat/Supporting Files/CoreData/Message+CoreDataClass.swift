//
//  Message+CoreDataClass.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/1/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Message)
public class Message: NSManagedObject {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
            
        createdAt = MPCChatUtility.getCurrentTime()
        modifiedAt = createdAt!
        
    }
    
    //Called everytime data is modified
    fileprivate func modified() -> (){
        modifiedAt = MPCChatUtility.getCurrentTime()
    }
    
    func createNew(_ uuid:String?=nil, withContent: String, owner: Peer) -> (){
        
        self.owner = owner
        self.owner.addToMessages(self) //Owner always owns message
        
        //created()
        updated(withContent)
        
        guard let currentUUID = uuid else {
            self.uuid = UUID.init().uuidString
            return
        }
        
        self.uuid = currentUUID
    }
    
    func updated(_ newContent:String)-> (){
        content = newContent
        modified()
    }
}
