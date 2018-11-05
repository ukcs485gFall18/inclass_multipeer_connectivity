//
//  BrowserModel.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/2/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class BrowserModel: NSObject{
    
    fileprivate var peerUUIDHash = [String:Int]()
    fileprivate var peerHashUUID = [Int:String]()
    fileprivate let appDelagate = UIApplication.shared.delegate as! AppDelegate
    fileprivate var thisPeer:Peer!
    
    var getPeerUUIDHashDictionary:[String:Int]{
        get{
            return peerUUIDHash
        }
    }
    
    var getPeerHashUUIDDictionary:[Int:String]{
        get{
            return peerHashUUID
        }
    }
    
    var getPeer: Peer{
        get{
            return thisPeer
        }
    }
    
    var getPeersFoundUUIDs:[String]{
        get{
            return peerUUIDHash.keys.map({$0})
        }
    }
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
    }
    
    func foundPeer(_ peerHash:Int, info: [String:String]?) -> () {
        //Add peers to both dictionaries
        
        guard let uuid = info?[kAdvertisingUUID] else{
            return
        }
        
        peerUUIDHash[uuid] = peerHash
        peerHashUUID[peerHash] = uuid
    }
    
    func lostPeer(_ peerHash:Int) -> (){
        //Remove from both dictionaries
        guard let uuid = peerHashUUID.removeValue(forKey: peerHash) else{
            return
        }
        
        _ = peerUUIDHash.removeValue(forKey: uuid)
    }
    
    func getPeerUUIDFromHash(_ peerHash: Int) -> String?{
        return peerHashUUID[peerHash]
    }
    
    func getPeerHashFromUUID(_ peerUUID: String) -> Int?{
        return peerUUIDHash[peerUUID]
    }
    
    func storeNewPeer(peerUUID: String, peerName: String, isConnectedToPeer: Bool, completion : (_ peer:Peer?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributepeerUUID) IN %@", [peerUUID]))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataPeers(compoundQuery, sortBy: kCoreDataPeerAttributeLastConnected, inDescendingOrder: true, completion: {
            
            (peersFound) -> Void in
            
            guard let peers = peersFound else{
                completion(nil)
                return
            }
            
            //Note: Should only receive 1 peer here, if you have more than you saving stuff incorrectly.
            guard let peer = peers.first else{
                
                //If there are 0 found, this must be a new item that needs to be stored to the local database
                let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                
                newPeer.createNew(peerUUID, peerName: peerName, connected: isConnectedToPeer)
                
                if save(){
                    completion(newPeer)
                }else{
                    print("Could not save newEntity for peer - \(peerName), with uuid value - \(peerUUID)")
                    discard()
                    completion(nil)
                }
            
                return
            }
            
            //ToDo: Need to update the lastTimeConnected when an item is already saved to CoreData. Hint should use, "peer" above to make update
            print("Found saved peer - \(peerName), with uuid value - \(peerUUID). Updated lastSeen information")
            completion(peer)
            
        })
    }
    

    @objc func handleCoreDataIsReady(_ notification: NSNotification){
        
        //Ensure MPCManager is up and running
        if (appDelagate.mpcManager == nil) || (!appDelagate.coreDataManager.isCoreDataReady){
            return
        }
        
        let (myPeerUUID, myPeerName) = (appDelagate.peerUUID, appDelagate.peerDisplayName)
        
        storeNewPeer(peerUUID: myPeerUUID, peerName: myPeerName, isConnectedToPeer: false, completion: {
            (storedPeer) -> Void in
            
            guard let peer = storedPeer else{
                print("Error in saving myself to CoreData")
                return
            }
            
            self.thisPeer = peer //Keep myself available for the life of the model
            print("Saved my info to CoreData")
        
        })
    }
    
    func findPeers(_ peerUUIDs: [String], completion : (_ peersFound:[Peer]?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributepeerUUID) IN %@", peerUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataPeers(compoundQuery, completion: {
            (peers) -> Void in
            
            completion(peers)
            
        })
    }
    
    func lastTimeSeenPeer(_ peerUUID: String, completion : (_ lastSeen: Date?, _ lastConnected: Date?) -> ()){
        
        findPeers([peerUUID], completion: {
            (peersFound) -> Void in
            
            guard let foundPeer = peersFound?.first else{
                completion(nil, nil)
                return
            }
            
            completion(foundPeer.lastSeen, foundPeer.lastConnected)
        })
    }
    
    func findRooms(_ roomUUIDs: [String], completion : (_ roomsFound:[Room]?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeUUID) IN %@", roomUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataRooms(compoundQuery, completion: {
            (rooms) -> Void in
            
            completion(rooms)
            
        })
    }
    
    func findRooms(_ owner: Peer, withPeer peer :Peer, completion : (_ roomsFound:[Room]?) -> ()){
        
        //Build query for this user as owner
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [owner], peer))
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [peer], owner))
        
        let compoundQuery = NSCompoundPredicate(orPredicateWithSubpredicates: predicateArray)
        
        var roomsToReturn = [Room]()
        
        appDelagate.coreDataManager.queryCoreDataRooms(compoundQuery, sortBy: kCoreDataRoomAttributeModifiedAt, inDescendingOrder: true, completion: {
            (roomsFound) -> Void in
            
            if roomsFound != nil{
                roomsToReturn.append(contentsOf: roomsFound!)
            }
            
            completion(roomsToReturn)
        })
    }
    
    func findOldChatRooms(_ ownerUUID: String, peerToJoinUUID: String, completion : (_ room:[Room]?) -> ()){
        
        findPeers([peerToJoinUUID], completion: {
            (peersFound) -> Void in
            
            guard let peer = peersFound?.first else{
                discard()
                completion(nil)
                return
            }
            
            findRooms(self.thisPeer, withPeer: peer, completion: {
                (roomsFound) -> Void in
                
                //ToDo: How do you modify this to return all rooms found related to the users?
                guard let room = roomsFound?.first else{
                    completion(nil)
                    return
                }
                
                completion([room])
                
            })
        })
    }
    
    func createNewChatRoom(_ ownerUUID: String, peerToJoinUUID: String, roomName: String, completion : (_ room:Room?) -> ()){
        
        let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: appDelagate.coreDataManager.managedObjectContext) as! Room
        
        findPeers([peerToJoinUUID], completion: {
            (peersFound) -> Void in
            
            guard let peer = peersFound?.first else{
                
                //The peer we are trying to add isn't in CoreData
                guard let peerHash = peerUUIDHash[peerToJoinUUID] else{
                    discard()
                    completion(nil)
                    return
                }
                
                guard let peerName = appDelagate.mpcManager.getPeerDisplayName(peerHash) else{
                    discard()
                    completion(nil)
                    return
                }
                //Store this peer
                storeNewPeer(peerUUID: peerToJoinUUID, peerName: peerName, isConnectedToPeer: false, completion: {
                    (storedPeer) -> Void in
                    
                    guard let peer = storedPeer else{
                        discard()
                        completion(nil)
                        return
                    }
                    
                    newRoom.createNew(roomName: roomName, owner: self.thisPeer)
                    newRoom.addToPeers(self.thisPeer)
                    newRoom.addToPeers(peer)
                    
                    if save(){
                        completion(newRoom)
                    }else{
                        print("Could not save newEntity for Room - \(roomName), with owner - \(self.thisPeer.uuid)")
                        discard()
                        completion(nil)
                    }
                })
                return
            }
            
            //Found all the peers needed, can save and move on
            newRoom.createNew(roomName: roomName, owner: self.thisPeer)
            newRoom.addToPeers(Set([self.thisPeer,peer]))
            
            if save(){
                completion(newRoom)
            }else{
                print("Could not save newEntity for Room - \(roomName), with owner - \(self.thisPeer.uuid)")
                discard()
                completion(nil)
            }
            
        })
    }
    
    func joinChatRoom(_ roomUUID: String, roomName: String, ownerUUID: String, ownerName: String, completion : (_ rooms:Room?) -> ()){
        
        findRooms([roomUUID], completion: {
            
            (roomsFound) -> Void in
            
            guard let rooms = roomsFound else{
                completion(nil)
                return
            }
            
            guard let oldRoom = rooms.first else{
                
                //If no room found, create a new room with the received roomUUID
                let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: appDelagate.coreDataManager.managedObjectContext) as! Room
                newRoom.addToPeers(self.thisPeer)
                
                //Get the owner as a Peer
                findPeers([ownerUUID], completion: {
                    (peersFound) -> Void in
                    
                    guard let peer = peersFound?.first else{
                        //If this owner has never been saved before, need to save
                        let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                        
                        newPeer.createNew(ownerUUID, peerName: ownerName, connected: false)
                        newRoom.createNew(roomUUID, roomName: roomName, owner: newPeer)
                        newRoom.addToPeers(newPeer)
                        newRoom.addToPeers(self.thisPeer)
                        
                        if save(){
                            completion(newRoom)
                        }else{
                            print("Could not save newEntity for Room - \(roomName), with owner - \(ownerUUID)")
                            discard()
                            completion(nil)
                        }
            
                        return
                    }
                    
                    //We've seen this peer before, just need a new room
                    newRoom.createNew(roomUUID, roomName: roomName, owner: peer)
                    newRoom.addToPeers(peer)
                    
                    
                    if save(){
                        completion(newRoom)
                    }else{
                        discard()
                    }
                })
                
                return
            }
            
            oldRoom.name = roomName //ToDo: Saves room name if sender has changed it. Fix this to check to make sure the person changing the room name is the owner
            oldRoom.addToPeers(self.thisPeer)
            
            findPeers([ownerUUID], completion: {
                (peersFound) -> Void in
                
                guard let peer = peersFound?.first else{
                    //If this peer has never been saved before, need to save to old room
                    let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                    
                    newPeer.createNew(ownerUUID, peerName: ownerName, connected: false)
                    oldRoom.addToPeers(newPeer)
                    
                    if save(){
                        completion(oldRoom)
                    }else{
                        discard()
                    }
                    
                    return
                }
                
                //We've seen this peer before, make sure they are added to the old room
                oldRoom.addToPeers(peer)
                
                if save(){
                    completion(oldRoom)
                }else{
                    discard()
                }
            })

        })
    }
    
    fileprivate func save()->Bool{
        return appDelagate.coreDataManager.saveContext()
    }
    
    fileprivate func discard()->(){
        appDelagate.coreDataManager.managedObjectContext.rollback()
    }
}
