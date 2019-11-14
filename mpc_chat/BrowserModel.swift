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
    
    /**
        Peers who have been invited that we are are waiting to hear back from
    */
    fileprivate var pendingInvitedPeers = [Int:[String:Any]]()
    
    
    /**
        Rooms that a we might want to ask a user to join
    */
    fileprivate var relatedRooms = [String:Room]()
    
    fileprivate var peersWhoTriedToConnect = [Int:String]()
    
    //MARK: Public variables
    
    /**
        Read-only value of the current users peerUUID. Note that peerUUID is private to this class and this is the only way to access it publicly. Read peerUUID for more info.
    */
    var thisUsersPeerUUID:String{
        get{
            return thisPeer.uuid
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
                
        //Just in case peerDisplayName hasn't been initialized yet. Sometimes this get's initialized early by CoreData
        if peerDisplayName == nil{
            peerDisplayName = MPCChatUtility.getDeviceName() //This is the display name for the device.
        }
        
        //This is a dictionary filled with advertisement information. This information is used to for other browsing users to know who you are
        guard let discovery = MPCChatUtility.buildAdvertisingDictionary() else{
            fatalError("Error in BroswerModel:init() couldn't buildAdvertisingDictionary")
        }
        
        //This is the unique user identifier for this user (UUID)
        guard let uuid = discovery[kAdvertisingUUID] else {
            fatalError("Error in BroswerModel:init() couldn't find \(kAdvertisingUUID) in discovery info, only found \(discovery)")
        }
        
        peerUUID = uuid
        
        //The class needes to become an observer of CoreData to know when it's ready to read/write data. When CoreData is ready, handleCoreDataIsReady() will be called automatically because we are observing.
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        
        //The class needes to become an observer of the MPCManager to know when users are able to be browsed and connections are ready to be establisehd. When MPCManager is ready, handleCoreDataIsReady() will be called automatically because we are observing.
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
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
            
            if mpcManager != nil{
                mpcManager.startAdvertising()
            }
        
            return
        }
        
        //Just in case peerDisplayName hasn't been initialized yet
        if peerDisplayName == nil{
            peerDisplayName = MPCChatUtility.getDeviceName() //This is the display name for the device.
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
            
            if mpcManager != nil{
                mpcManager.startAdvertising()
            }
            
        })
        
    }
    
    /**
        Queries CoreData for all stored rooms that are related to the Peer and withPeer. Asynchronously returns all rooms that were found
        
        - parameters:
            - owner: The Peer who owns the rooms you are looking for
            - withPeer: The other Peer who is in the room with the owner you are looking for
            - roomsFound: An array of rooms found related to the owner and withPeer
     
    */
    fileprivate func findRooms(_ owner: Peer, withPeer peer: Peer, withRoomUUID roomID: String?=nil, completion : (_ roomsFound:[Room]?) -> ()){
        
        //Build query for this user as owner.

        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [owner], peer))
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeOwner) IN %@ AND %@ IN \(kCoreDataRoomAttributePeers)", [peer], owner))
        
        if roomID != nil{
            predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeUUID) == %@", roomID!))
        }
        
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
        roomToJoin = nil
        peersWhoTriedToConnect.removeAll()
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
    
    
    func invitePeer(_ peerHash: Int, info: [String:Any]){
        
        pendingInvitedPeers[peerHash] = info
        mpcManager.invitePeer(peerHash, additionalInfo: info)
    }
    
    func clearRoomsRelatedToPeer(){
        relatedRooms.removeAll()
    }
    
    func deviceIsAdvertising()->Bool{
        return mpcManager.deviceIsAdvertising
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
    
    fileprivate func whatTypeOfPeerIsDevice(_ ownerUUID: String?=nil, peerToJoinUUID: String?=nil)->(owner:Peer?, peerToJoin:Peer?, uuidToSearch: String?){
        
        //Check if this method was used correctly
        if ownerUUID == nil && peerToJoinUUID == nil{
            print("Error in BrowserModel.whatTypeOfPeerIsDevice(). Both ownerUUID and peerToJoinUUID can't be nil. Only set the one to nil that belongs to this specific device")
            return (nil,nil,nil)
        }
        
        var owner:Peer? = nil
        var peerToJoin:Peer? = nil
        var peerToSearchUUID:String? = nil
        
        //Check to see if this peer is the owner or a member in the room. Note the if statement at the top of the method confirms that both can't be nil
        if ownerUUID == nil {
            owner = self.thisPeer
            peerToSearchUUID = peerToJoinUUID!
        } else if peerToJoinUUID == nil{
            peerToJoin = self.thisPeer
            peerToSearchUUID = ownerUUID!
        } else if ownerUUID! == self.thisPeer.uuid{
            //This means the user provided both UUID's, so we can unwrap it. One of these should be the owner
            owner = self.thisPeer
            peerToSearchUUID = peerToJoinUUID!
        } else if peerToJoinUUID! == self.thisPeer.uuid{
            //This means the user provided both UUID's, , so we can unwrap it, One of these should be the owner
            peerToJoin = self.thisPeer
            peerToSearchUUID = ownerUUID!
        } else{
            print("Error in BrowserModel.whatTypeOfPeerIsDevice(). None of the UUID's passed to this method belong to this device, ignoring...")
        }
        
        return (owner,peerToJoin,peerToSearchUUID)
        
    }
    
    func findOldChatRooms(_ ownerUUID: String?=nil, peerToJoinUUID: String?=nil, roomUUID: String?=nil, completion : (_ roomInformation:[String:[String:String]]) -> ()){
        
        //Build invite information to send to user
        var roomInfo = [String:[String:String]]()
        
        var (owner,peerToJoin,peerToSearchUUID) = whatTypeOfPeerIsDevice(ownerUUID, peerToJoinUUID: peerToJoinUUID)
        
        //Check if this method was used correctly
        if owner == nil && peerToJoin == nil && peerToSearchUUID == nil{
            print("Error in BrowserModel.findOldChatRooms(). Both owner and peerToJoin can't be nil. Only set the one to nil that belongs to this specific device")
            completion(roomInfo)
            return
        }
        
        BrowserModel.findPeers([peerToSearchUUID!], completion: {
            (peersFound) -> Void in

            guard let peerFound = peersFound?.first else{
                completion(roomInfo)
                return
            }
                           
            //If a previous CoreData Peer entity wasn't set, the peerFound belongs to that entity
            if owner == nil{
                owner = peerFound
            }else{
                peerToJoin = peerFound
            }

            //If we made it this far, the owner and Peer have succesfully been set, so it's safe to unwrap both of them and search for the rooms they belong to.
            findRooms(owner!, withPeer: peerToJoin!, withRoomUUID: roomUUID, completion: {
                (roomsFound) -> Void in
                
                //MARK: - HW3: How do you modify this to return all rooms found related to the users?
                guard let rooms = roomsFound else{
                    completion(roomInfo)
                    return
                }
                
                for room in rooms{
                    roomInfo[room.uuid] = [
                        kCommunicationsRoomName: room.name,
                        kCommunicationsRoomOwnerUUID: room.owner.uuid
                    ]
                    relatedRooms[room.uuid] = room
                }
            
                completion(roomInfo)
                
            })
        })
        
    }
    
    func createTemporaryRoom(_ peerHash: Int, peerDisplayName:String?=nil, uuidOfRoom: String?=nil, nameOfRoom:String?=nil, ownerOfRoomUUID:String?=nil)->[String:String]{
        
        let roomUUID:String
        if uuidOfRoom != nil{
            roomUUID = uuidOfRoom!
        }else{
            roomUUID = UUID.init().uuidString
        }
        
        let roomName:String
        if nameOfRoom != nil{
            roomName = nameOfRoom!
        }else if peerDisplayName != nil{
            roomName = "Chat w/ \(peerDisplayName!)" //Probably want to come up with better default room name
        }else{
            roomName = "None"
        }
        
        let ownerUUID:String
        if ownerOfRoomUUID != nil{
            ownerUUID = ownerOfRoomUUID!
        }else{
            ownerUUID = self.thisPeer.uuid
        }
            
    
        //Build invite information to send to user
        let temporaryRoomInfo = [
            kCommunicationsRoomUUID: roomUUID,
            kCommunicationsRoomName: roomName,
            kCommunicationsRoomOwnerUUID: ownerUUID
        ]
        
        self.pendingInvitedPeers[peerHash] = temporaryRoomInfo
        
        return temporaryRoomInfo
        
    }
    
    func wantPeerToJoinRoom(_ peerHash:Int, completion : (_ room:Room?) -> ()){
        
        guard let roomInfo = pendingInvitedPeers[peerHash],
            let roomUUID = roomInfo[kCommunicationsRoomUUID] as? String,
            let roomName = roomInfo[kCommunicationsRoomName] as? String,
            let roomOwnerUUID = roomInfo[kCommunicationsRoomOwnerUUID] as? String else{
                
            print("Error in BrowserModel.wantPeerToJoinRoom(). the roomInfo for \(peerHash) wasn't found in \(pendingInvitedPeers)")
            completion(nil)
            return
        }
        
        guard let potentialRoom = relatedRooms[roomUUID] else{
            
            guard let otherPeerUUID = self.getPeerUUIDFromHash(peerHash) else{
                print("Error in BrowserModel.wantPeerToJoinRoom() couldn't find UUID for hash \(peerHash)")
                return
            }
            
            let peerToJoinChatUUID:String
           
            if roomOwnerUUID != self.thisPeer.uuid {
                peerToJoinChatUUID = self.thisPeer.uuid
            }else{
                peerToJoinChatUUID = otherPeerUUID
            }
            
            //If a room isn't found above, a new room must be created
            createNewChatRoom(roomOwnerUUID, peerUUID: peerToJoinChatUUID, roomUUID: roomUUID, roomName: roomName, completion: {
            (createdRoom) -> Void in
            
                guard let room = createdRoom else{
                    completion(nil)
                    return
                }
            
                completion(room)
                return
            })
            
            return
        }
        
        completion(potentialRoom)
        
    }
    
    func createNewChatRoom(_ owner: String, peerUUID: String, roomUUID:String?=nil, roomName: String, completion : (_ room:Room?) -> ()){
        
        var (owner, peerToJoin, peerUUIDToSearch) = whatTypeOfPeerIsDevice(owner, peerToJoinUUID: peerUUID)
        
        //Check if this method was used correctly
        if owner == nil && peerToJoin == nil && peerUUIDToSearch == nil{
            print("Error in BrowserModel.createNewChatRoom(). Both owner and peerToJoin can't be nil. Only set the one to nil that belongs to this specific device")
            completion(nil)
            return
        }
        
        let newRoom = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityRoom, into: coreDataManager.managedObjectContext) as! Room
        
        BrowserModel.findPeers([peerUUIDToSearch!], completion: {
            (peersFound) -> Void in
            
            guard let peerFound = peersFound?.first else{
                
                //We entered in this statement if the peer we are trying to add isn't in CoreData, so we need to add them to CoreData first
                
                //Get the hash value for the current peer
                guard let peerHash = peerUUIDHash[peerUUIDToSearch!] else{
                    discard()
                    completion(nil)
                    return
                }
                
                guard let peerName = mpcManager.getPeerDisplayName(peerHash) else{
                    discard()
                    completion(nil)
                    return
                }
                
                //Store this peer in CoreData
                storeNewPeer(peerUUID: peerUUID, peerName: peerName, isConnectedToPeer: false, completion: {
                    (storedPeer) -> Void in
                    
                    guard let peerFound = storedPeer else{
                        discard()
                        completion(nil)
                        return
                    }
                    
                    //If a previous CoreData Peer entity wasn't set, the peerFound belongs to that entity
                    if owner == nil{
                        owner = peerFound
                    }else{
                        peerToJoin = peerFound
                    }
                    
                    newRoom.createNew(roomUUID, roomName: roomName, owner: owner!)
                    newRoom.addToPeers(Set([owner!, peerToJoin!]))
                    
                    if save(){
                        completion(newRoom)
                    }else{
                        print("Could not save newEntity for Room - \(roomName), with owner - \(owner!.uuid)")
                        discard()
                        completion(nil)
                    }
                })
                return
            }
            
            //If a previous CoreData Peer entity wasn't set, the peerFound belongs to that entity
            if owner == nil{
                owner = peerFound
            }else{
                peerToJoin = peerFound
            }
            
            //Found all the peers needed, can save and move on
            newRoom.createNew(roomUUID, roomName: roomName, owner: owner!)
            newRoom.addToPeers(Set([owner!, peerToJoin!]))
            
            if save(){
                completion(newRoom)
            }else{
                print("Could not save newEntity for Room - \(roomName), with owner - \(self.thisPeer.uuid)")
                discard()
                completion(nil)
            }
            
        })
    }
    
    func hasThisPeerTriedToConnectBefore(peerHash: Int, peerDisplayName: String)->Bool{
        //If this user has already tried to connect before, ignore them...
        if peersWhoTriedToConnect[peerHash] != nil{
            return true
        }else{
            //Store this peer temporalily just incase they keep bothering you. They can only alert you once
            self.peersWhoTriedToConnect[peerHash] = peerDisplayName
            return false
        }
        
    }
    
    func joinChatRoom(_ fromPeerHash:Int, roomInfo: [String:Any], completion : (_ okToJoin:Bool) -> ()){
        
        guard let roomUUID = roomInfo[kCommunicationsRoomUUID] as? String,
            let roomName = roomInfo[kCommunicationsRoomName] as? String,
            let roomOwnerUUID = roomInfo[kCommunicationsRoomOwnerUUID] as? String else{
                print("Error in BrowserModel.joinChatRoom(). RoomUUID, RoomName, or RoomOwnerUUID is missing from invite \(roomInfo)")
            return
        }
        
        BrowserModel.findRooms([roomUUID], completion: {
            
            (roomsFound) -> Void in
            
            //There should only be one room found for this roomUUID since roomUUIDs are unique
            guard let oldRoom = roomsFound?.first else{
                
                _ = createTemporaryRoom(fromPeerHash, uuidOfRoom: roomUUID, nameOfRoom: roomName, ownerOfRoomUUID: roomOwnerUUID)
                
                completion(true)
                return
            }
            
            oldRoom.name = roomName //MARK: - HW3: Saves room name if sender has changed it. Fix this to check to make sure the person changing the room name is the owner. If not, it should ignore
            
            self.relatedRooms[roomUUID] = oldRoom
            
            guard let fromPeerUUID = getPeerUUIDFromHash(fromPeerHash),
                let fromPeerDisplayName = getPeerDisplayName(fromPeerHash) else{
                print("Error in BrowserModel.joinChatRoom() couldn't get UUID for peer hash \(fromPeerHash)")
                return
            }
            
            BrowserModel.findPeers([fromPeerUUID], completion: {
                (peersFound) -> Void in
                
                guard let _ = peersFound?.first else{
                    
                    //If this peer has never been saved before
                    let newPeer = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeer, into: coreDataManager.managedObjectContext) as! Peer
                    newPeer.createNew(fromPeerUUID, peerName: fromPeerDisplayName, connected: false)
                    //newPeer.createNew(roomOwnerUUID, peerName: roomOwnerName, connected: false)
                    //oldRoom.addToPeers(newPeer)
                    
                    if save(){
                        self.pendingInvitedPeers[fromPeerHash] = roomInfo
                        completion(true)
                    }else{
                        discard()
                        completion(false)
                    }
                    
                    return
                }
                
                //We've seen this peer before, make sure they are added to the old room
                //oldRoom.addToPeers(peer)
                
                if save(){
                    self.pendingInvitedPeers[fromPeerHash] = roomInfo
                    completion(true)
                }else{
                    discard()
                    completion(false)
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
    func peerDeniedConnection(_ peerHash: Int, peerName: String) {
        if pendingInvitedPeers[peerHash] != nil{
            print("BrowserModel.peerDeniedConnection() peer \(peerName) with hash \(peerHash) denied invitation")
        }
    }
    
    
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
        
        wantPeerToJoinRoom(peerHash, completion: {
            (roomToJoin) -> Void in
            
            //Remove the key for the pending invites
            _ = pendingInvitedPeers.removeValue(forKey: peerHash)
            self.clearRoomsRelatedToPeer()
            
            guard let room = roomToJoin else{
                return
            }
                        
            self.roomToJoin = room //Set the room to join
            
            //Update information stored information about this peer
            storeNewPeer(peerUUID: peerUUID, peerName: peerName, isConnectedToPeer: true, completion: {
                (storedPeer) -> Void in
                
                if storedPeer == nil{
                    print("Couldn't store peer info, disconnecting from \(peerName) with uuid \(peerUUID)")
                    mpcManager.disconnect()
                    
                }else{
                    
                    OperationQueue.main.addOperation{ () -> Void in
                        //Send notification that view needs to segue to ChatRoom. Notice how this needs to be called on the main thread
                        NotificationCenter.default.post(name: Notification.Name(rawValue: kNotificationBrowserHasAddedUserToRoom), object: self)
                    }
                }
            })
        })
        
    }
}
