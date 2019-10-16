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
    
    var curentBrowserModel:BrowserModel!
    
    var getPeer: Peer{
        get{
            return thisPeer
        }
    }
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatModel.handleChatRoomHasBeenUpdated(_:)), name: Notification.Name(rawValue: kNotificationBrowserHasAddedUserToRoom), object: nil)
    }
    
    convenience init(browserModel: BrowserModel){
        self.init()
        
        curentBrowserModel = browserModel
        
        guard let roomToJoin = curentBrowserModel.roomToJoin else{
            fatalError("Error")
        }
        
        thisRoom = roomToJoin
        thisPeer = curentBrowserModel.getPeer
        peerUUIDHash = curentBrowserModel.getPeerUUIDHashDictionary
        peerHashUUID = curentBrowserModel.getPeerHashUUIDDictionary
        
        curentBrowserModel.setMPCMessageManagerDelegate(self)
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
    
    func addPeer(_ peerHash:Int, peerUUID: String) -> () {
        
        //Add peers to both dictionaries
        peerUUIDHash[peerUUID] = peerHash
        peerHashUUID[peerHash] = peerUUID
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
        
        //HW3: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
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
    
    //MARK: Notification receivers
    
    @objc func handleChatRoomHasBeenUpdated(_ notification: Notification) {
        
        BrowserModel.findRooms([thisRoom.uuid], completion: {
            (roomsFound) -> Void in
            
            guard let newRoom = roomsFound?.first else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). No room was found")
                return
            }
            
            thisRoom = newRoom //Update to the latest version of room
            
            guard let uuidOfPeerAddedToChat = notification.userInfo?[kNotificationChatPeerUUIDKey] as? String else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). \(kNotificationChatPeerUUIDKey) was not found in notification dictionary")
                return
            }
            
            
            guard let hashOfPeerAddedToChat = getPeerHashFromUUID(uuidOfPeerAddedToChat) else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). Couldn't get the hashID for peer with UUID \(uuidOfPeerAddedToChat)")
                return
            }
            
            addPeer(hashOfPeerAddedToChat, peerUUID: uuidOfPeerAddedToChat)
            
            //Send notification to ViewController that peer has been added to the Chat
            NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatRefreshRoom), object: self, userInfo: [kNotificationChatPeerHashKey : hashOfPeerAddedToChat])
        })
    }
    
}

//MARK: MPCManagerMessageDelegate methods
extension ChatModel: MPCManagerMessageDelegate {
    
    func peerDisconnected(_ peerHash: Int, peerName: String) {
        
        //Check to see if this is a peer we were connected to
        lostPeer(peerHash, completion: {
            (success) -> Void in
            
            if success{
                
                //HW3: Need to update the lastTimeConnected when an item is already saved to CoreData. This is when you disconnected from the user. Hint: use peerHash to find peer.
                
                //Notify ViewController the peer was lost
                NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatPeerWasLost), object: self, userInfo: [kNotificationChatPeerNameKey: peerName])
            }
            
        })
        
    }
    
    func messageReceived(_ fromPeerHash:Int, data: Data) {
        
        //Convert the data (Data) into a Dictionary object
        let dataDictionary = NSKeyedUnarchiver.unarchiveObject(with: data) as! [String:String]
        
        //Check if there's an entry with the kCommunicationsMessageContentTerm key
        guard let message = dataDictionary[kCommunicationsMessageContentTerm] else{
            return
        }
        
        if message != kCommunicationsEndConnectionTerm  {
            
            //HW3: Hint, this is checking for kCommunicationsMessageUUIDTerm, what if we checked for kBrowserPeerRoomName to detect a room name?
            guard let uuid = dataDictionary[kCommunicationsMessageUUIDTerm] else{
                print("Error: received messaged is lacking UUID")
                return
            }
            
            guard let fromPeerUUID = getPeerUUIDFromHash(fromPeerHash) else{
                return
            }
            
            storeNewMessage(uuid, content: message, fromPeer: fromPeerUUID, completion: {
                (messageReceived) -> Void in
                
                guard let message = messageReceived else{
                    return
                }
                
                //Notify ViewController that a new message was posted
                NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatNewMessagePosted), object: self, userInfo: [kNotificationChatPeerMessageKey: message])
                
            })
            
        }else{
            //fromPeerHash want's to disconnect
            print("\(fromPeerHash) is about to End this chat, prepare for disconnecton.")
            
        }
    }
    
}

