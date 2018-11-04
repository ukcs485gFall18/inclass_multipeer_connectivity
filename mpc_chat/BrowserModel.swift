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
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
    }
    
    let appDelagate = UIApplication.shared.delegate as! AppDelegate
    
    func storeNewPeer(peerHash: Int, peerName: String, isConnectedToPeer: Bool, completion : (_ stored:Bool) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributePeerHash) IN %@", [peerHash]))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataPeers(compoundQuery, sortBy: kCoreDataPeerAttributeLastConnected, inDescendingOrder: true, completion: {
            
            (peersFound) -> Void in
            
            guard let peers = peersFound else{
                completion(false)
                return
            }
            
            //Note: Should only receive 1 peer here, if you have more than you saving stuff incorrectly.
            guard let peer = peers.first else{
                
                //If there are 0 found, this is must be a new item that needs to be store to the local database
                let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                
                newPeer.createNew(peerHash, peerName: peerName, connected: isConnectedToPeer)
                
                if save(){
                    completion(true)
                }else{
                    print("Could not save newEntity for peer - \(peerName), with hash value - \(peerHash)")
                    discard()
                    completion(false)
                }
            
                return
            }
            
            //ToDo: Need to update the lastTimeConnected when an item is already saved to CoreData. Hint should use, "peer" above to make update
            print("Found saved peer - \(peerName), with hash value - \(peerHash). Updated lastSeen information")
            completion(true)
            
        })
    }
    

    @objc func handleCoreDataIsReady(_ notification: NSNotification){
        
        //Ensure MPCManager is up and running
        if (appDelagate.mpcManager == nil) || (!appDelagate.isCoreDataAvailable){
            return
        }
        
        let (myPeerHash, myPeerName) = appDelagate.mpcManager.getMyPeerInfo()
        storeNewPeer(peerHash: myPeerHash, peerName: myPeerName, isConnectedToPeer: false, completion: {
            (success) -> Void in
            
            if success{
                print("Saved my info to CoreData")
            }else{
                print("Error in saving myself to CoreData")
            }
            
        })
    }
    
    func findPeers(_ peerHashes: [Int], completion : (_ peersFound:[Peer]?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributePeerHash) IN %@", peerHashes))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataPeers(compoundQuery, completion: {
            (peers) -> Void in
            
            completion(peers)
            
        })
    }
    
    func lastTimeSeenPeer(_ peerHash:Int, completion : (_ lastSeen:Date?, _ lastConnected:Date?) -> ()){
        
        findPeers([peerHash], completion: {
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
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeCreatedAt) IN %@", roomUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        appDelagate.coreDataManager.queryCoreDataRooms(compoundQuery, completion: {
            (rooms) -> Void in
            
            completion(rooms)
            
        })
    }
    
    func createNewChatRoom(_ ownerHash: Int, roomName: String, completion : (_ room:Room?) -> ()){
        
        let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: appDelagate.coreDataManager.managedObjectContext) as! Room
        
        findPeers([ownerHash], completion: {
            (peersFound) -> Void in
            
            guard let peer = peersFound?.first else{
                discard()
                completion(nil)
                return
            }
            
            newRoom.createNew(roomName, owner: peer)
            newRoom.addToPeers(peer)
            
            if save(){
                completion(newRoom)
            }else{
                print("Could not save newEntity for Room - \(roomName), with owner - \(ownerHash)")
                discard()
                completion(nil)
            }
            
        })
    }
    
    func joinChatRoom(_ roomUUID: String, roomName: String, ownerHash: Int, ownerName: String, completion : (_ rooms:Room?) -> ()){
        
        findRooms([roomUUID], completion: {
            
            (roomsFound) -> Void in
            
            guard let rooms = roomsFound else{
                completion(nil)
                return
            }
            
            guard let oldRoom = rooms.first else{
                //If no room found, create a new room
                let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: appDelagate.coreDataManager.managedObjectContext) as! Room
                
                findPeers([ownerHash], completion: {
                    (peersFound) -> Void in
                    
                    guard let peer = peersFound?.first else{
                        //If this peer has never been saved before, need to save
                        let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                        
                        newPeer.createNew(ownerHash, peerName: ownerName, connected: false)
                        newRoom.createNew(roomName, owner: newPeer)
                        newRoom.addToPeers(newPeer)
                        
                        if save(){
                            completion(newRoom)
                        }else{
                            print("Could not save newEntity for Room - \(roomName), with owner - \(ownerHash)")
                            discard()
                            completion(nil)
                        }
            
                        return
                    }
                    
                    //We've see this peer before, just need a new room
                    newRoom.createNew(roomName, owner: peer)
                    newRoom.addToPeers(peer)
                    
                    if save(){
                        completion(newRoom)
                    }else{
                        discard()
                    }
                })
                
                return
            }
            
            findPeers([ownerHash], completion: {
                (peersFound) -> Void in
                
                guard let peer = peersFound?.first else{
                    //If this peer has never been saved before, need to save
                    let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: appDelagate.coreDataManager.managedObjectContext) as! Peer
                    
                    newPeer.createNew(ownerHash, peerName: ownerName, connected: false)
                    oldRoom.createNew(roomName, owner: newPeer)
                    oldRoom.addToPeers(newPeer)
                    
                    if save(){
                        completion(oldRoom)
                    }else{
                        discard()
                    }
                    
                    return
                }
                
                //We've see this peer before, make sure they are added to the old room
                oldRoom.addToPeers(peer)
                completion(oldRoom)
            })

        })
    }
    
    func save()->Bool{
        return appDelagate.coreDataManager.saveContext()
    }
    
    func discard()->(){
        appDelagate.coreDataManager.managedObjectContext.rollback()
    }
}
