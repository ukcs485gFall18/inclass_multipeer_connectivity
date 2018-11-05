//
//  Room+CoreDataClass.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/1/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Room)
public class Room: NSManagedObject {
    
    private func created() -> () {
        
        //If a time was already created, never change it
        if createdAt == nil{
            createdAt = MPCChatUtility.getCurrentTime()
            modifiedAt = createdAt!
        }
    }
    
    //Called everytime data is modified
    fileprivate func modified() -> (){
        modifiedAt = MPCChatUtility.getCurrentTime()
    }
    
    func createNew(_ roomUUID:String?=nil, roomName: String, owner: Peer) -> (){
    
        self.owner = owner
        self.addToPeers(owner) //Owner always belongs to a room
        self.owner.addToPeersInRooms(self)
        created()
        updated(roomName)
        
        guard let thisUUID = roomUUID else{
            self.uuid = UUID.init().uuidString
            return
        }
        
        self.uuid  = thisUUID
    }
    
    func updated(_ roomName:String)-> (){
        name = roomName
        modified()
    }
    
}
