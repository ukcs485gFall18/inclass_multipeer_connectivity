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

    //MARK: Private variables
    /**
        All wireless connectivity for the application
    */
    fileprivate var mpcManager: MPCManager!
    
    /**
        the UUID of this particular peer
    */
    fileprivate var peerUUID:String!
    
    /**
        the display name of this particular user
    */
    fileprivate var peerDisplayName:String!
    
    /**
        A dictionary of all users found by the browser wirelessly. The keys are UUID's and the values are unique hash values for a particular device
    */
    fileprivate var peerUUIDHash = [String:Int]()
    
    /**
        A dictionary of all users found by the browser wirelessly. The keys are hashes's of a particular device and the values are UUIDs for a particular user. Note that this is the reverse of peerUUIDHash. Both of these are kept for faster searching. If we didn't have both, and we wanted to find what hash value belonged to a particular UUID, we would have to search peerUUIDHash linearly using a for loop which can be slow if there are alot of users discovered in the browser.
    */
    fileprivate var peerHashUUID = [Int:String]()
    
    /**
        This is a singleton to query anything we need from CoreData
    */
    fileprivate let coreDataManager = CoreDataManager.sharedCoreDataManager
    
    /**
        The CoreData representaton of this particular entity
    */
    fileprivate var thisPeer:Peer!
    
    /**
        The CoreData representaton of the room the user wants to join
    */
    fileprivate var roomToJoin:Room?
    
    //MARK: Public variables
    
    /**
        Read-only value of the current users peerUUID. Note that peerUUID is private to this class and this is the only way to access it publicly. Read peerUUID for more info.
    */
    var thisUsersPeerUUID:String{
        get{
            return peerUUID
        }
    }
    
    /**
        Read-only value of the peerHashUUID dictionary. Note that peerHashUUID is private to this class and this is the only way to access it publicly. Read peerHashUUID for more info.
    */
    var getPeerHashUUIDDictionary:[Int:String]{
        get{
            return peerHashUUID
        }
    }
    
    /**
        Read-only value of the peerUUIDHash dictionary. Note that peerUUIDHash is private to this class and this is the only way to access it publicly. Read peerUUIDHash for more info.
    */
    var getPeerUUIDHashDictionary:[String:Int]{
        get{
            return peerUUIDHash
        }
    }
    
    /**
        Read-only value of the thisPeer dictionary. Note that thisPeer is private to this class and this is the only way to access it publicly. Read thisPeer for more info.
    */
    var getPeer: Peer{
        get{
            return thisPeer
        }
    }
    
    /**
        Read-only value of the key values of the peerUUIDHash dictionary. Note that this is a computed value and this is the only way to access it publicly. Read peerUUIDHash for more info about it's key values.
    */
    var getPeersFoundUUIDs:[String]{
        get{
            return peerUUIDHash.keys.map({$0})
        }
    }
    
    /**
        Read/Write the specific roomToJoin. Note that roomToJoin is private to this class and this is the only way to access it publicly

        - returns: The name of the peer as a String
     
    */
    var roomPeerWantsToJoin:Room?{
        get{
            return roomToJoin
        }
        set{
            roomToJoin = newValue
        }
    }
    
    
    /**
        Initializes a new BrowserModel to began wireless discovery and connectivity
     
    */
    override init() {
        super.init()
        
        //The class needes to become an observer of CoreData to know when it's ready to read/write data. When CoreData is ready, handleCoreDataIsReady() will be called automatically because we are observing.
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        
        //The class needes to become an observer of the MPCManager to know when users are able to be browsed and connections are ready to be establisehd. When MPCManager is ready, handleCoreDataIsReady() will be called automatically because we are observing.
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
        
        peerDisplayName = MPCChatUtility.getDeviceName() //This is the display name for the device.
        
        //This is a dictionary filled with advertisement information. This information is used to for other browsing users to know who you are
        guard let discovery = MPCChatUtility.buildAdvertisingDictionary() else{
            fatalError("Error in BroswerModel:init() couldn't buildAdvertisingDictionary")
        }
        
        //This is the unique user identifier for this user (UUID)
        guard let uuid = discovery[kAdvertisingUUID] else {
            fatalError("Error in BroswerModel:init() couldn't find \(kAdvertisingUUID) in discovery info, only found \(discovery)")
        }
        
        peerUUID = uuid
        
        //Instantiate the MPCManager so we can browse for users and create connections
        self.mpcManager = MPCManager(kAppName, advertisingName: peerDisplayName, discoveryInfo: discovery)
        
        //Become a delegate of the MPCManager instance so we act when a users are found and invitations are receiced. See MPCManagerDelegate to see how we conform to the protocol
        mpcManager.managerDelegate = self
        
    }
    
    
    //MARK: Private methods - these are used internally by the BrowserModel only
    /**
        Checks to see if CoreData is ready. If CoreData is ready, then the updated values of this user is stored. This is in case the user changes their displayName. If CoreData isn't ready, this method does nothing. This is called whenever the notification that references this method is fired.
         - important:
            - This method is made available to objective-c hence the @objc in front of it's declaration. This is required since part of the Notificaiton Center is still written on Objective-C. Swift will complain if this isn't there and will automatically add it back
     
        - parameters:
            - notification: Has additional informaiton that was sent from the notifier
     
    */
    @objc fileprivate func handleCoreDataIsReady(_ notification: Notification){
        
        //If CoreData isn't ready, we are not allowed to do anything with the database, doing so will crash the application
        if !coreDataManager.isCoreDataReady{
            return
        }
        
        //If thisPeer was already set, there's no need to set it again
        if self.thisPeer != nil{
            return
        }
        
        //This is an example of how to create a tuple along with declaring two values at the same time. It's not really necessary here, but doing it as an ecxample
        let (myPeerUUID, myPeerName) = (peerUUID!, peerDisplayName!)
        
        //Store this peer as a Peer entity in CoreData for later usage
        storeNewPeer(peerUUID: myPeerUUID, peerName: myPeerName, isConnectedToPeer: false, completion: {
            (storedPeer) -> Void in
            
            //Try to unwrap storedPeer, this should unwrap if it was stored in CoreData properly
            guard let peer = storedPeer else{
                print("Error in BrowswerModel().handleCoreDataIsReady(). Couldn't save myself as a Peer entity in CoreData")
                return
            }
            
            self.thisPeer = peer //Update myself with the stored value from CoreData
            print("Successfully saved my updated info to CoreData")
        })
        
    }
    
    /**
        Queries CoreData for all stored rooms that are related to the Peer and withPeer. Asynchronously returns all rooms that were found
        
        - parameters:
            - owner: The Peer who owns the rooms you are looking for
            - withPeer: The other Peer who is in the room with the owner you are looking for
            - roomsFound: An array of rooms found related to the owner and withPeer
     
    */
    fileprivate func findRooms(_ owner: Peer, withPeer peer: Peer, completion : (_ roomsFound:[Room]?) -> ()){
        
        //Build query for this user as owner.
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [owner], peer))
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [peer], owner))
        
        let compoundQuery = NSCompoundPredicate(orPredicateWithSubpredicates: predicateArray)
        
        //Create an array of rooms that currently contains 0 rooms
        var roomsToReturn = [Room]()
        
        coreDataManager.queryCoreDataRooms(compoundQuery, sortBy: kCoreDataRoomAttributeModifiedAt, inDescendingOrder: true, completion: {
            (roomsFound) -> Void in
            
            //If rooms ware found, add them to the array of rooms created earlier
            if roomsFound != nil{
                roomsToReturn.append(contentsOf: roomsFound!)
            }
            
            //Asynchronously return the array of rooms found, even if none were found
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
            
            //MARK: - HW3: Need to update the lastTimeConnected when an item is already saved to CoreData. Hint should use, "peer" above to make update
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
                
                //MARK: - HW3: How do you modify this to return all rooms found related to the users?
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
            
            oldRoom.name = roomName //MARK: - HW3: Saves room name if sender has changed it. Fix this to check to make sure the person changing the room name is the owner
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
    
    //MARK: - HW3: Fix BrowserTable refreshing/reloading when MPC Manager refreshes and "Peers" is the segment selected
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
