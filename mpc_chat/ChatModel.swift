//
//  ChatModel.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/3/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class ChatModel: NSObject{
    
    fileprivate let coreDataManager = CoreDataManager.sharedCoreDataManager
    fileprivate var peerUUIDHash:[String:Int]!
    fileprivate var peerHashUUID:[Int:String]!
    fileprivate var thisPeer:Peer!
    fileprivate var thisRoom:Room!
    
    var getPeer: Peer{
        get{
            return thisPeer
        }
    }
    
    override init() {
        super.init()
    }
    
    convenience init(peer: Peer, peerUUIDHashDictionary: [String:Int], peerHashUUIDDictionary: [Int:String], room: Room) {
        self.init()
        thisPeer = peer
        peerUUIDHash = peerUUIDHashDictionary
        peerHashUUID = peerHashUUIDDictionary
        thisRoom = room
    }
    
    //MARK: Private methods
    
    fileprivate func findMessages(_ messageUUIDs: [String], completion : (_ messagesFound:[Message]?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataMessageAttributeUUID) IN %@", messageUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        //This is how you find sorted data
        coreDataManager.queryCoreDataMessages(compoundQuery, sortBy: kCoreDataMessageAttributeCreatedAt, inDescendingOrder: false, completion: {
            (messagesFound) -> Void in
            
            completion(messagesFound)
            
        })
    }
    
    fileprivate func save()->Bool{
        return coreDataManager.saveContext()
    }
    
    fileprivate func discard()->(){
        coreDataManager.managedObjectContext.rollback()
    }
    
    //MARK: Public methods

    func getAllMessagesInRoom(completion : (_ sortedMessages:[Message]?) -> ()){
        
        var messageUUIDs = [String]()
        
        guard let messages = thisRoom.messages else {
            completion(nil)
            return
        }
        
        //These messages are coming from a Set and are probably not sorted the way we want them, so we need to get the UUID's and ask CoreData to give it to us sorted
        for message in messages {
            messageUUIDs.append(message.uuid)
        }
        
        if messageUUIDs.count == 0{
            completion(nil)
            return
        }
        
        findMessages(messageUUIDs, completion: {
            
            (messagesFound) -> Void in
            
            guard let messages = messagesFound else{
                completion(nil)
                return
            }
            
            completion(messages)
        })
    }
    
    func foundPeer(_ peerHash:Int, info: [String:String]?) -> () {
        //Add peers to both dictionaries
        
        guard let uuid = info?[kAdvertisingUUID] else{
            return
        }
        
        peerUUIDHash[uuid] = peerHash
        peerHashUUID[peerHash] = uuid
        
        BrowserModel.updateLastTimeSeenPeer([uuid])
    }
    

    func lostPeer(_ peerHash:Int, completion: (_ lostPeerInThisRoom: Bool) -> ()){
        //Remove from both dictionaries
        guard let uuid = peerHashUUID.removeValue(forKey: peerHash) else{
            completion(false)
            return
        }
        
        _ = peerUUIDHash.removeValue(forKey: uuid)
        
        //Check to see if the peer lost was in this room
        BrowserModel.findPeers([uuid], completion: {
            (peers) -> Void in
            
            guard let peer = peers?.first else{
                completion(false)
                return
            }
            
            if thisRoom.peers.contains(peer){
                completion(true)
            }else{
                completion(false)
            }
        })
    
    }
    
    func getPeerUUIDFromHash(_ peerHash: Int) -> String?{
        return peerHashUUID[peerHash]
    }
    
    func getPeerHashFromUUID(_ peerUUID: String) -> Int?{
        return peerUUIDHash[peerUUID]
    }
    
    func getRoomName() -> String{
        return thisRoom.name
    }
    
    func changeRoomName(_ name:String) ->(){
        
        //ToDo: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
        let oldRoomName = thisRoom.name
        thisRoom.updated(name)
        
        if save(){
            print("Successfully changed room name from \(oldRoomName) to \(thisRoom.name)")
        }else{
            print("Could not save changes of room name")
        }
    }
    
    func storeNewMessage(_ uuid: String?=nil, content: String, fromPeer: String, completion : (_ message:Message?) -> ()){
        
        //Find peer in CoreData
        BrowserModel.findPeers([fromPeer], completion: {
            (peerFound) -> Void in
            
            guard let peer = peerFound?.first else{
                return
            }
            
            let newMessage = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityMessage, into: coreDataManager.managedObjectContext) as! Message
            
            newMessage.createNew(uuid, withContent: content, owner: peer)
            thisRoom.addToMessages(newMessage)
            thisRoom.modified()
            if save(){
                completion(newMessage)
            }else{
                discard()
                completion(nil)
            }
            
        })
        
    }
    
    
}

