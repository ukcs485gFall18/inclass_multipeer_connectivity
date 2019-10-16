//
//  BrowserModel.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/2/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import CoreData

class BrowserModel: NSObject{

    fileprivate var mpcManager: MPCManager!
    var peerUUID:String!
    var peerDisplayName:String!
    fileprivate var peerUUIDHash = [String:Int]()
    fileprivate var peerHashUUID = [Int:String]()
    fileprivate let coreDataManager = CoreDataManager.sharedCoreDataManager
    //fileprivate let appDelagate = UIApplication.shared.delegate as! AppDelegate
    fileprivate var thisPeer:Peer!
    var roomToJoin:Room?

    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataIsReady), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
        
        peerDisplayName = MPCChatUtility.getDeviceName() //This is the display name for the device.
        
        guard let discovery = MPCChatUtility.buildAdvertisingDictionary() else{
            fatalError("Error in BroswerModel:init() couldn't buildAdvertisingDictionary")
        }
        
        guard let uuid = discovery[kAdvertisingUUID] else {
            fatalError("Error in BroswerModel:init() couldn't find \(kAdvertisingUUID) in discovery info, only found \(discovery)")
        }
        
        peerUUID = uuid
        
        self.mpcManager = MPCManager(kAppName, advertisingName: peerDisplayName, discoveryInfo: discovery)
        
        mpcManager.managerDelegate = self
        
    }
    
    
    //MARK: Private methods
    @objc fileprivate func handleCoreDataIsReady(_ notification: Notification){
        
        if !coreDataManager.isCoreDataReady{
            return
        }
        
        //If already set, no need to do again
        if self.thisPeer != nil{
            return
        }
        
        let (myPeerUUID, myPeerName) = (peerUUID!, peerDisplayName!)
        
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
    
    fileprivate func findRooms(_ owner: Peer, withPeer peer :Peer, completion : (_ roomsFound:[Room]?) -> ()){
        
        //Build query for this user as owner
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [owner], peer))
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [peer], owner))
        
        let compoundQuery = NSCompoundPredicate(orPredicateWithSubpredicates: predicateArray)
        
        var roomsToReturn = [Room]()
        
        coreDataManager.queryCoreDataRooms(compoundQuery, sortBy: kCoreDataRoomAttributeModifiedAt, inDescendingOrder: true, completion: {
            (roomsFound) -> Void in
            
            if roomsFound != nil{
                roomsToReturn.append(contentsOf: roomsFound!)
            }
            
            completion(roomsToReturn)
        })
    }
    
    fileprivate func save()->Bool{
        return coreDataManager.saveContext()
    }
    
    fileprivate func discard()->(){
        coreDataManager.managedObjectContext.rollback()
    }
    
    
    //MARK: Public methods
    func setMPCMessageManagerDelegate(_ toBecomeDelegate: MPCManagerMessageDelegate){
        mpcManager.messageDelegate = toBecomeDelegate
    }
    
    func setMPCInvitationManagerDelegate(_ toBecomeDelegate: MPCManagerInvitationDelegate){
        mpcManager.invitationDelegate = toBecomeDelegate
    }
    
    func getPeerDisplayName(_ peerHash: Int)-> String?{
        return mpcManager.getPeerDisplayName(peerHash)
    }
    
    func getPeerUUIDFromHash(_ peerHash: Int) -> String?{
        return peerHashUUID[peerHash]
    }
    
    func getPeerHashFromUUID(_ peerUUID: String) -> Int?{
        return peerUUIDHash[peerUUID]
    }
    
    func disconnect(){
        mpcManager.disconnect()
    }
    
    func sendData(dictionaryWithData: [String:String], toPeers: [Int]) -> Bool {
        return mpcManager.sendData(dictionaryWithData: dictionaryWithData, toPeers: toPeers)
    }
    
    func storeNewPeer(peerUUID: String, peerName: String, isConnectedToPeer: Bool, completion : (_ peer:Peer?) -> ()){
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributePeerUUID) IN %@", [peerUUID]))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        coreDataManager.queryCoreDataPeers(compoundQuery, sortBy: kCoreDataPeerAttributeLastConnected, inDescendingOrder: true, completion: {
            
            (peersFound) -> Void in
            
            guard let peers = peersFound else{
                completion(nil)
                return
            }
            
            //Note: Should only receive 1 peer here, if you have more than you saving stuff incorrectly.
            guard let peer = peers.first else{
                
                //If there are 0 found, this must be a new item that needs to be stored to the local database
                let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: coreDataManager.managedObjectContext) as! Peer
                
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
            
            //HW3: Need to update the lastTimeConnected when an item is already saved to CoreData. Hint should use, "peer" above to make update
            print("Found saved peer - \(peer.peerName), with uuid value - \(peerUUID). Updated lastSeen information")
            completion(peer)
            
        })
    }
    
    func lastTimeSeenPeer(_ peerUUID: String, completion : (_ lastSeen: Date?, _ lastConnected: Date?) -> ()){
        
        BrowserModel.findPeers([peerUUID], completion: {
            (peersFound) -> Void in
            
            guard let foundPeer = peersFound?.first else{
                completion(nil, nil)
                return
            }
            
            completion(foundPeer.lastSeen, foundPeer.lastConnected)
        })
    }
    
    
    func invitePeer(_ peerHash: Int, info: [String:Any]?){
        mpcManager.invitePeer(peerHash, additionalInfo: info)
    }
    
    func getIsAdvertising()->Bool{
        return mpcManager.getIsAdvertising
    }
    
    func stopAdvertising(){
        mpcManager.stopAdvertising()
    }
    
    func startAdvertising(){
        mpcManager.startAdvertising()
    }
    
    func getPeersConnectedTo()->[Int]{
        return mpcManager.getPeersConnectedTo()
    }
    
    func findOldChatRooms(peerToJoinUUID: String, completion : (_ room:[Room]?) -> ()){
        
        BrowserModel.findPeers([peerToJoinUUID], completion: {
            (peersFound) -> Void in
            
            guard let peer = peersFound?.first else{
                discard()
                completion(nil)
                return
            }
            
            findRooms(self.thisPeer, withPeer: peer, completion: {
                (roomsFound) -> Void in
                
                //HW3: How do you modify this to return all rooms found related to the users?
                guard let room = roomsFound?.first else{
                    completion(nil)
                    return
                }
                
                completion([room])
                
            })
        })
    }
    
    func createNewChatRoom(_ peerToJoinUUID: String, roomName: String, completion : (_ room:Room?) -> ()){
        
        let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: coreDataManager.managedObjectContext) as! Room
        
        BrowserModel.findPeers([peerToJoinUUID], completion: {
            (peersFound) -> Void in
            
            guard let peer = peersFound?.first else{
                
                //The peer we are trying to add isn't in CoreData
                guard let peerHash = peerUUIDHash[peerToJoinUUID] else{
                    discard()
                    completion(nil)
                    return
                }
                
                guard let peerName = mpcManager.getPeerDisplayName(peerHash) else{
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
        
        BrowserModel.findRooms([roomUUID], completion: {
            
            (roomsFound) -> Void in
            
            guard let rooms = roomsFound else{
                completion(nil)
                return
            }
            
            guard let oldRoom = rooms.first else{
                
                //If no room found, create a new room with the received roomUUID
                let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: coreDataManager.managedObjectContext) as! Room
                newRoom.addToPeers(self.thisPeer)
                
                //Get the owner as a Peer
                BrowserModel.findPeers([ownerUUID], completion: {
                    (peersFound) -> Void in
                    
                    
                    //Build dictionary of user information to send
                    let notificationInfo = [
                        kNotificationChatPeerUUIDKey: ownerUUID
                    ]
                        
                    guard let peer = peersFound?.first else{
                        //If this owner has never been saved before, need to save
                        let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: coreDataManager.managedObjectContext) as! Peer
                        
                        newPeer.createNew(ownerUUID, peerName: ownerName, connected: false)
                        newRoom.createNew(roomUUID, roomName: roomName, owner: newPeer)
                        newRoom.addToPeers(newPeer)
                        newRoom.addToPeers(self.thisPeer)
                        
                        if save(){
                            
                            OperationQueue.main.addOperation{ () -> Void in
                                //Send notification that room has changed. This is needed for cases when the BrowserModel is used to add additional users to a room
                                NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserHasAddedUserToRoom), object: self, userInfo: notificationInfo)
                            }
                            
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
                        
                        OperationQueue.main.addOperation{ () -> Void in
                            //Send notification that room has changed. This is needed for cases when the BrowserModel is used to add additional users to a room
                            NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserHasAddedUserToRoom), object: self, userInfo: notificationInfo)
                        }
                        
                        completion(newRoom)
                    }else{
                        discard()
                    }
                })
                
                return
            }
            
            oldRoom.name = roomName //HW3: Saves room name if sender has changed it. Fix this to check to make sure the person changing the room name is the owner
            oldRoom.addToPeers(self.thisPeer)
            
            BrowserModel.findPeers([ownerUUID], completion: {
                (peersFound) -> Void in
                
                guard let peer = peersFound?.first else{
                    //If this peer has never been saved before, need to save to old room
                    let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: coreDataManager.managedObjectContext) as! Peer
                    
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
    
    //MARK: Class methods, these are utility methods that multiple class may want to use
    
    class func findPeers(_ peerUUIDs: [String], completion : (_ peersFound:[Peer]?) -> ()){
        
        let coreDataManager = CoreDataManager.sharedCoreDataManager
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributePeerUUID) IN %@", peerUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        coreDataManager.queryCoreDataPeers(compoundQuery, completion: {
            (peers) -> Void in
            
            completion(peers)
            
        })
        
    }
    
    class func updateLastTimeSeenPeer(_ peerUUIDs: [String]) -> (){
        BrowserModel.findPeers(peerUUIDs, completion: {
            (peersFound) -> Void in
            
            guard let foundPeers = peersFound else{
                //Do nothing if this peer isn't in CoreData
                return
            }
            
            for peer in foundPeers {
                peer.updateLastSeen()
            }
        })
    }
    
    class func findRooms(_ roomUUIDs: [String], completion : (_ roomsFound:[Room]?) -> ()){
        
        let coreDataManager = CoreDataManager.sharedCoreDataManager
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeUUID) IN %@", roomUUIDs))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        coreDataManager.queryCoreDataRooms(compoundQuery, completion: {
            (rooms) -> Void in
            
            completion(rooms)
            
        })
    }
    
}

// MARK: - MPCManager delegate methods implementation
extension BrowserModel: MPCManagerDelegate{
    
    //HW3: Fix BrowserTable refreshing/reloading when MPC Manager refreshes and "Peers" is the segment selected
    func foundPeer(_ peerHash: Int, withInfo: [String:String]?) {
        
        guard let uuid = withInfo?[kAdvertisingUUID] else{
            return
        }
        
        peerUUIDHash[uuid] = peerHash
        peerHashUUID[peerHash] = uuid
        
        BrowserModel.updateLastTimeSeenPeer([uuid])
        
        OperationQueue.main.addOperation{ () -> Void in
            //Send notification that view needs to be refreshed. Notice how this needs to be called main thread
            NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserScreenNeedsToBeRefreshed), object: self)
        }
    }
    
    func lostPeer(_ peerHash: Int) {
        
        //Remove from both dictionaries
        guard let uuid = peerHashUUID.removeValue(forKey: peerHash) else{
            return
        }
        
        _ = peerUUIDHash.removeValue(forKey: uuid)
        
        OperationQueue.main.addOperation{ () -> Void in
            //Send notification that view needs to be refreshed. Notice how this needs to be called on the main thread
            NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserScreenNeedsToBeRefreshed), object: self)
        }
    }
    

    func connectedWithPeer(_ peerHash: Int, peerName: String) {
        
        guard let peerUUID = getPeerUUIDFromHash(peerHash) else{
            return
        }
        
        storeNewPeer(peerUUID: peerUUID, peerName: peerName, isConnectedToPeer: true, completion: {
            (storedPeer) -> Void in
            
            if storedPeer == nil{
                print("Couldn't store peer info, disconnecting from \(peerName) with uuid \(peerUUID)")
                mpcManager.disconnect()
                
            }else{
                
                OperationQueue.main.addOperation{ () -> Void in
                    //Send notification that view needs to segue to ChatRoom. Notice how this needs to be called on the main thread
                    NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserConnectedToFirstPeer), object: self)
                }
            }
        })
    }
}
