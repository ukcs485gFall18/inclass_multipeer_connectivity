//
//  ChatModel.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/3/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import CoreData

class ChatModel: NSObject{
    
    fileprivate let coreDataManager = CoreDataManager.sharedCoreDataManager
    fileprivate var peerUUIDHash:[String:Int]!
    fileprivate var peerHashUUID:[Int:String]!
    fileprivate var thisPeer:Peer!
    fileprivate var room:Room!
    fileprivate var currentBrowserModel:BrowserModel!
    
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
        
        currentBrowserModel = browserModel
        
        guard let roomToJoin = currentBrowserModel.roomPeerWantsToJoin else{
            fatalError("Error in ChatModel(browserModel: BrowserModel). Attempted to join a chat room, but the roomPeerWantsToJoin was never set.")
        }
        
        room = roomToJoin
        thisPeer = currentBrowserModel.getPeer
        peerUUIDHash = currentBrowserModel.getPeerUUIDHashDictionary
        peerHashUUID = currentBrowserModel.getPeerHashUUIDDictionary
        
        currentBrowserModel.becomeMessageDelegate(self)
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

    func becomeBrowserModelConnectedDelegate(_ toBecomeDelegate: BrowserModelConnectedDelegate){
        currentBrowserModel.browserConnectedDelegate = toBecomeDelegate
    }
    
    func getPeersConnectedTo()->[Int]{
        return currentBrowserModel.getPeersConnectedTo()
    }
    
    func sendData(data: [String:String], toPeers: [Int]) -> Bool {
        
        var returnValue = false
            
        if currentBrowserModel.sendData(dictionaryWithData: data, toPeers: toPeers){
            if !save(){
                print("Error in ChatModel.sendData(). Wasn't able to save data after send. The message '\(data)' to Peers '\(toPeers)' will not be persisted to CoreData")
            }
            returnValue = true
        }
            
        return returnValue
    }
    
    func disconnect(){
        currentBrowserModel.disconnect()
    }
    
    func thisUsersPeerUUID()->String{
        return currentBrowserModel.thisUsersPeerUUID
    }
    
    func getPeerDisplayName(_ peerHash: Int)-> String?{
        return currentBrowserModel.getPeerDisplayName(peerHash)
    }
    
    func getAllMessagesInRoom(completion : (_ sortedMessages:[Message]?) -> ()){
        
        var messageUUIDs = [String]()
        
        guard let messages = room.messages else {
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
            
            if room.peers.contains(peer){
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
        return room.name
    }
    
    func changeRoomName(_ name:String) ->(){
        
        //MARK: - HW3: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
        let oldRoomName = room.name
        room.updated(name)
        
        if save(){
            print("Successfully changed room name from \(oldRoomName) to \(room.name)")
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
            room.addToMessages(newMessage)
            room.modified()
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
        
        BrowserModel.findRoom(room.uuid, completion: {
            (roomFound) -> Void in
            
            guard let newRoom = roomFound else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). No room was found")
                return
            }
            
            room = newRoom //Update to the latest version of room
            
            guard let uuidOfPeerAddedToChat = notification.userInfo?[kNotificationChatPeerUUIDKey] as? String else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). \(kNotificationChatPeerUUIDKey) was not found in notification dictionary")
                return
            }
            
            
            guard let hashOfPeerAddedToChat = getPeerHashFromUUID(uuidOfPeerAddedToChat) else{
                print("Error in ChatModel.handleChatRoomHasBeenUpdated(). Couldn't get the hashID for peer with UUID \(uuidOfPeerAddedToChat)")
                return
            }
            
            addPeer(hashOfPeerAddedToChat, peerUUID: uuidOfPeerAddedToChat)
            
            OperationQueue.main.addOperation{ () -> Void in
                //Send notification to ViewController that peer has been added to the Chat. Notice how this needs to be called on the main thread
                NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatRefreshRoom), object: self, userInfo: [kNotificationChatPeerHashKey : hashOfPeerAddedToChat])
            }
        })
    }
    
}

//MARK: MPCManagerMessageDelegate methods
extension ChatModel: MPCManagerMessageDelegate {
    
    func peerDisconnected(_ peerHash: Int, peerName: String) {
        
        //Check to see if this is a peer we were connected to
        lostPeer(peerHash, completion: {
            (wasPeerInThisRoom) -> Void in
            
            if wasPeerInThisRoom{
                
                //MARK: - HW3: Need to update the lastTimeConnected when an item is already saved to CoreData. This is when you disconnected from the user. Hint: use peerHash to find peer.
                
                OperationQueue.main.addOperation{ () -> Void in
                
                    //Notify ViewController the peer was lost. Notice how this needs to be called on the main thread
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatPeerWasLost), object: self, userInfo: [kNotificationChatPeerNameKey: peerName])
                }
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
            
            //MARK: - HW3: Hint, this is checking for kCommunicationsMessageUUIDTerm, what if we checked for kCommunicationsRoomName to detect a room name?
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
                
                OperationQueue.main.addOperation{ () -> Void in
                    //Notify ViewController that a new message was posted. Notice how this needs to be called on the main thread
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationChatNewMessagePosted), object: self, userInfo: [kNotificationChatPeerMessageKey: message])
                }
                
            })
            
        }else{
            //fromPeerHash want's to disconnect
            print("\(fromPeerHash) is about to End this chat, prepare for disconnecton.")
            
        }
    }
    
}

