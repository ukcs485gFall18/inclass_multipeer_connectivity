//
//  Peer+CoreDataClass.swift
//  mpc_chat
//
//  Created by Baker, Corey on 10/25/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Peer)
public class Peer: NSManagedObject {
    
    fileprivate func created() -> () {
        
        //If a time was already created, never change it
        if createdAt == nil{
            createdAt = MPCChatUtility.getCurrentTime()
            modifiedAt = createdAt!
            lastSeen = createdAt!
        }
    }
    
    //Called everytime data is modified
    fileprivate func modified() -> (){
        modifiedAt = MPCChatUtility.getCurrentTime()
    }
    
    func createNew(_ peerUUID: String, peerName: String, connected:Bool) -> (){
        self.uuid = peerUUID
        self.peerName = peerName
        
        created()
        update(connected: connected)
    }
    
    func update(_ peerName:String?=nil, connected:Bool)-> (){
        if let newPeerName = peerName{
            self.peerName = newPeerName
        }
        
        modified()
        
        if connected{
            updateConnected()
        }
        
    }
    
    func updateLastSeen()-> (){
        let currentTime = MPCChatUtility.getCurrentTime()
        
        if currentTime > lastSeen{
            lastSeen = currentTime
            modified()
        }
        
    }
    
    fileprivate func updateConnected()-> (){
        lastConnected = MPCChatUtility.getCurrentTime()
    }
    
}
