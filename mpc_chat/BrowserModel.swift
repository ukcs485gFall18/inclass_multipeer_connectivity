//
//  BrowserModel.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/2/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation
import CoreData

protocol BrowserModelDelegate {
    /**

        - parameters:
            - fromPeerHash: The hash value for the peer that was found
            - additionalInfo: Additional information provided from peer
            - completion: fromPeer is the hash value of the peer you want to respond to. accept is a bool value stating if you want to connect to peer or not
     
    */
    func respondToInvitation(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void)
}

protocol BrowserModelConnectedDelegate {
    /**

        - parameters:
            - fromPeerHash: The hash value for the peer that was found
            - additionalInfo: Additional information provided from peer
            - completion: fromPeer is the hash value of the peer you want to respond to. accept is a bool value stating if you want to connect to peer or not
     
    */
    func respondToInvitation(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void)
}

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
    
    /**
        Peers that have asked to join while this user was in a connection. It's used to block their notifications
    */
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
        Any class who wishes to be delegated to when this peer receives an invitation while disconned.
        
    */
    var browserDelegate:BrowserModelDelegate?
    
    /**
        Any class who wishes to be delegated to when this peer receives an invitation while MPC Manager is connected
        
    */
    var browserConnectedDelegate:BrowserModelConnectedDelegate?
    
    
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
        
        //The class needes to become an observer of CoreData to know when it's ready to read/write data. When CoreData is ready, handleCoreDataIsReady() will be called automatically because we are observing. Note that CoreData and MPCManager both need to be ready to start browsing and connecting
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        
        //The class needes to become an observer of the MPCManager to know when users are able to be browsed and connections are ready to be establisehd. When MPCManager is ready, handleCoreDataIsReady() will be called automatically because we are observing. Note that CoreData and MPCManager both need to be ready to start browsing and connecting
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserModel.handleCoreDataIsReady(_:)), name: Notification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
        
        //Instantiate the MPCManager so we can browse for users and create connections
        self.mpcManager = MPCManager(kAppName, advertisingName: peerDisplayName, discoveryInfo: discovery)

        //Become a delegate of the MPCManager instance so we act when a users are found and invitations are received. See MPCManagerDelegate to see how we conform to the protocol
        mpcManager.managerDelegate = self
        
    }
    
    
    //MARK: Private methods - these are used internally by the BrowserModel only
    /**
        Checks to see if CoreData is ready. If CoreData is ready, then the updated values of this user is stored. This is in case the user changes their displayName. If CoreData isn't ready, this method does nothing. This is called whenever the notification that references this method is fired. It also checks to make sure MPCManager is ready to start browsing user and connecting.
         - important:
            - This method is made available to Objective-C hence the @objc in front of it's declaration. This is required since part of the Notificaiton Center is still written on Objective-C. Swift will complain if this isn't there and will automatically add it back
     
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
    fileprivate func findRooms(_ owner: Peer, withPeer peer: Peer, completion : (_ roomsFound:[Room]?) -> ()){
        
        //Build query for this user as owner.

        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "%@ == \(kCoreDataRoomAttributeOwner) AND %@ IN \(kCoreDataRoomAttributePeers)", owner, peer))
        predicateArray.append(NSPredicate(format: "%@ == \(kCoreDataRoomAttributeOwner) AND %@ IN \(kCoreDataRoomAttributePeers)", peer, owner))
        
        let compoundQuery = NSCompoundPredicate(orPredicateWithSubpredicates: predicateArray)
        
        //Create an array of rooms that currently contains 0 rooms
        var roomsToReturn = [Room]()
        
        coreDataManager.queryCoreDataRooms(compoundQuery, sortBy: kCoreDataRoomAttributeCreatedAt, inDescendingOrder: true, completion: {
            (roomsFound) -> Void in
            
            //If rooms ware found, add them to the array of rooms created earlier
            if roomsFound != nil{
                roomsToReturn.append(contentsOf: roomsFound!)
            }
            
            //Asynchronously return the array of rooms found, even if none were found
            completion(roomsToReturn)
        })
    }
    
    /**
        Persists all created entities to CoreData
     
    */
    fileprivate func save()->Bool{
        return coreDataManager.saveContext()
    }
    
    /**
        Discards any changes made to the undo stack and restors CoreData back to it's previous state
     
    */
    fileprivate func discard()->(){
        coreDataManager.managedObjectContext.rollback()
    }
    

    //MARK: Public methods - these can be used by any outside class
    /**
        Allows any class who conforms to the MPCManagerMessageDelegate protocol to be notified when messages are received along with being notified when a connection has been disconnected
        
        - parameters:
            - toBecomeDelegate: The class that wishes to become a delegate
    */
    func becomeMessageDelegate(_ toBecomeDelegate: MPCManagerMessageDelegate){
        mpcManager.messageDelegate = toBecomeDelegate
    }
    
    /**
        Gets the current Display Name of a peer from a uniqe hash value. Note that each broadcasting peer has it's own hashValue. So two peers can have the same displayName and can be the same person, but each device they own will broadcast a different hash. The hash value allows you to identify what device is communicating with you. Display names are not unique, as an all users essentiall can have the same display name.
        
        - parameters:
            - peerHash: The unique hash value of the peer you want the displayName for
    */
    func getPeerDisplayName(_ peerHash: Int)-> String?{
        return mpcManager.getPeerDisplayName(peerHash)
    }
    
    /**
        Gets the current UUID of a peer from a uniqe hash value. Note that each broadcasting peer has it's own hashValue. So two peers can have the same UUID and can be the same person, but each device they own will broadcast a different hash. The hash value allows you to identify what device is communicating with you. An individual user will have 1 UUID that is used across multiple devices (meaning different hashes)
        
        - parameters:
            - peerHash: The unique hash value of the peer you want the displayName for
    */
    func getPeerUUIDFromHash(_ peerHash: Int) -> String?{
        return peerHashUUID[peerHash]
    }
    
    /**
        Gets the current hashValue of a peer from a UUID.
        - parameters:
            - peerUUID: The UUID that you are looking for the hash for
    */
    func getPeerHashFromUUID(_ peerUUID: String) -> Int?{
        return peerUUIDHash[peerUUID]
    }
    
    /**
        Allows you to disconnect from the current chatroom, assuming you are already connected. Note that all chat information received/sent is saved before the disconnection occurs to ensure data isn't lost
    */
    func disconnect(){
        
        if !save(){
            print("Error in BrowserModel.disconnect(). Couldn't save to CoreData before disconnecting")
        }
        
        roomToJoin = nil
        peersWhoTriedToConnect.removeAll()
        mpcManager.disconnect()
    }
    
    /**
        Sends messages to peers of specific hashValues
        - parameters:
            - dictionaryWithData: A dictionary of key value strings to be sent to the connected peers
            - toPeers: An array of peers hashValues to should receive the message. Note that if you only want to send the message to 1 user, only one hashValue is needed in the array
    */
    func sendData(dictionaryWithData: [String:String], toPeers: [Int]) -> Bool {
        return mpcManager.sendData(dictionaryWithData: dictionaryWithData, toPeers: toPeers)
    }
    
    /**
        Saves a specific state "asynchronously" of a peer to this devices CoreData. Note that if a Peer changes their particular Peer entity on their device, your device will not update until this method is called again
        - parameters:
            - peerUUID: The unique identifier of the peer to save in String form
            - peerName: The display Name of the peer to save in String form
            - isConnectedToPeer: A boolean determining if the current state to store was connected to the Peer
            - completion: The asyncronous return block which is returned after all saving has been completed on the background thread
            - peer: The CoreData Peer entity returned after the asynchronous completion block is returned
    */
    func storeNewPeer(peerUUID: String, peerName: String, isConnectedToPeer: Bool, completion : (_ peer:Peer?) -> ()){
        
        //Note that when querying the database, you can make a sophisticated query by making any combination of NSPredicate's. Below is a very simple query
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataPeerAttributePeerUUID) == %@", peerUUID))
        
        //Now you can use NSCompoundPredicate and decide if you want to "and" or "or" the predicates in the array. For this particular query, you can "and" or "or" as they will yield the same result
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        //This is an asyncronous call to CoreData asking for it to search the Peers entity for all data matching the query above
        coreDataManager.queryCoreDataPeers(compoundQuery, sortBy: kCoreDataPeerAttributeLastConnected, inDescendingOrder: true, completion: {
            
            (peersFound) -> Void in
            
            //Once the quering is completed, we check to see if any peers were found matching the query
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
    
    /**
        "Asynchronously" get the last time a specific peer was seen and connected to
        - parameters:
            - peerUUID: The unique identifier of the peer to save in String form
            - completion: The asyncronous return block which is returned after all saving has been completed on the background thread
            - lastSeen: The Date when this peer was last seen in the browser. Note this also has all time components because of the Date class. This is returned after the asynchronous completion block is ready
            - lastConnected: The Date when this peer was last connected in the same chatroom with this Peer. Note this also has all time components because of the Date class. This is returned after the asynchronous completion block is ready
    */
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
    
    /**
        Invites a peer that has  the uniqe hash value of peerHash. You also send the peer any meaning "info" such as Room owner and name characteristics to help them determine if they want to connect with you
        
        - parameters:
            - peerHash: The unique hash value of the peer
            - info: The unique hash value of the peer
    */
    func invitePeer(_ peerHash: Int, info: [String:Any]){
        
        pendingInvitedPeers[peerHash] = info
        //Tell the MPCManager to send invitation infomation to this peer
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
    
    /**
        Get all peers you are currently connected to
        
        - returns:
            - An array of uniqueHash values of all Peer devices you are connected to
    */
    func getPeersConnectedTo()->[Int]{
        return mpcManager.getPeersConnectedTo()
    }
    
    /**
        Determine if your current device is the Owner of the Chat Room room you are about to join or if you are simpley a Member of the ChatRoom
        - parameters:
            - ownerUUID: The unique identifier of the owner of the room in String form. This value defaults to nil if none is specified
            - peerToJoinUUID: The unique identifier of the peer who will be joining the room in String form. This value defaults to nil if none is specified

        - returns:
            - owner: The CoreData entity form of the Owner of the room, Note that value can be nil if the Owner couldn't be determined or found in CoreData
            - peerToJoin: The CoreData entity form of the Peer who is joining the room, Note that value can be nil if the peerToJoin couldn't be determined or found in CoreData
            - uuidToSearch: The string value of the uuid that couldn't be found for the "owner" or "peerToJoin". Note that this device is always either a "owner" or the "peerToJoin", so if this returns nil, it means the ownerUUID or peerToJoinUUID were specified incorrectly or something is wrong with the app
    */
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
    
    /**
        "Asynchronously" finds all saved chat rooms in CoreData where between ownerUUID and peerToJoinUUID
        - parameters:
            - ownerUUID: The unique identifier of the owner of the room in String form. This value defaults to nil if none is specified
            - peerToJoinUUID: The unique identifier of the peer who will be joining the room in String form. This value defaults to nil if none is specified
            - completion: The asyncronous return block which is returned after all saving has been completed on the background thread
            - lastSeen: The Date when this peer was last seen in the browser. Note this also has all time components because of the Date class. This is returned after the asynchronous completion block is ready
            - lastConnected: The Date when this peer was last connected in the same chatroom with this Peer. Note this also has all time components because of the Date class. This is returned after the asynchronous completion block is ready
    */
    func findOldChatRooms(_ ownerUUID: String?=nil, peerToJoinUUID: String?=nil, completion : (_ roomInformation:[String:[String:String]]) -> ()){
        
        //Build invite information to send to user
        var roomInfo = [String:[String:String]]()
        
        var (owner,peerToJoin,peerToSearchUUID) = whatTypeOfPeerIsDevice(ownerUUID, peerToJoinUUID: peerToJoinUUID)
        
        //Check if whatTypeOfPeerIsDevice method was used correctly and returned valid information (check the comments of this method for more info)
        if owner == nil && peerToJoin == nil && peerToSearchUUID == nil{
            print("Error in BrowserModel.findOldChatRooms(). Both owner and peerToJoin can't be nil. Only set the one to nil that belongs to this specific device")
            completion(roomInfo)
            return
        }
        
        //Asyncronously find the peer of peerToSearchUUID. Note that we can safely force unwrap "peerToSearchUUID" because it was checked in the if statement above
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
            findRooms(owner!, withPeer: peerToJoin!, completion: {
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
    
    /**
        When preparing to establish a connection, temporary room information is stored and only used if a connection is "physically" established between the two peers
        - parameters:
            - peerHash: The unique identifier of the owner of the room in String form. This value defaults to nil if none is specified
            - peerDisplayName: The displayName of the peer we are preparing to join a room with in String form. This value defaults to nil if none is specified
            - uuidOfRoom: The unique identifier of the room we are preparting to join in String form. This value defaults to nil if none is specified
            - nameOfRoom: The name of the room we are planning to join in String form. This value defaults to nil if none is specified
            - ownerOfRoomUUID: The unique identifier of the owner of the room we are preparing to join in String form. This value defaults to nil if none is specified
        - returns:
            - a temporary dictionary array that can be used to seend to the other peer
    */
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
    
    func createNewChatRoom(_ ownerUUID: String, peerUUID: String, roomUUID:String?=nil, roomName: String, completion : (_ room:Room?) -> ()){
        
        var (owner, peerToJoin, peerUUIDToSearch) = whatTypeOfPeerIsDevice(ownerUUID, peerToJoinUUID: peerUUID)
        
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
                storeNewPeer(peerUUID: peerUUIDToSearch!, peerName: peerName, isConnectedToPeer: false, completion: {
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
        
        BrowserModel.findRoom(roomUUID, completion: {
            
            (roomFound) -> Void in
            
            //There should only be one room found for this roomUUID since roomUUIDs are unique
            guard let oldRoom = roomFound else{
                
                _ = createTemporaryRoom(fromPeerHash, uuidOfRoom: roomUUID, nameOfRoom: roomName, ownerOfRoomUUID: roomOwnerUUID)
                
                completion(true)
                return
            }
            
            oldRoom.name = roomName //MARK: - HW3: Saves room name if sender has changed it. Fix this to check to make sure the person changing the room name is the owner. If not, it should ignore
            
            //Debug
            print("Owner: \(oldRoom.owner.uuid)")
            for peer in oldRoom.peers {
                print(peer.peerName)
                print(peer.uuid)
            }
            
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
    
    class func findRoom(_ roomUUID: String, completion : (_ roomFound:Room?) -> ()){
        
        let coreDataManager = CoreDataManager.sharedCoreDataManager
        
        var predicateArray = [NSPredicate]()
        predicateArray.append(NSPredicate(format: "\(kCoreDataRoomAttributeUUID) == %@", roomUUID))
        
        let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: predicateArray)
        
        coreDataManager.queryCoreDataRooms(compoundQuery, completion: {
            (rooms) -> Void in
            
            guard let room = rooms?.first else{
                completion(nil)
                return
            }
            
            completion(room)
            
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
    
    func invitationReceived(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void) {
        
        guard let peerDisplayName = mpcManager.getPeerDisplayName(fromPeerHash) else{
            print("Error in BrowserModel.invitationReceived(). Couldn't get displayName for \(fromPeerHash)")
            completion(fromPeerHash, false)
            return
        }
        
        //Prepare notification information to send to any class that is Observing
        var informationReceived = additionalInfo
        informationReceived[kNotificationBrowserPeerDisplayName] = peerDisplayName
        
        //If the user is connected to anyone, deny all invitations received
        if mpcManager.getPeersConnectedTo().count > 0{
            
            if self.hasThisPeerTriedToConnectBefore(peerHash: fromPeerHash, peerDisplayName: peerDisplayName){
                //Do nothing and ignore the peer
                completion(fromPeerHash, false)
                return
            }
            
            
            browserConnectedDelegate?.respondToInvitation(fromPeerHash, additionalInfo: informationReceived, completion: completion)
            
        }else{
        
            guard let roomName = additionalInfo[kCommunicationsRoomName] as? String else{
                print("Error in BrowserModel.invitationReceived(). RoomName is missing from invite \(additionalInfo)")
                return
            }
        
            //Add the room to join to the notificaiton
            informationReceived[kNotificationBrowserRoomName] = roomName
            
            browserDelegate?.respondToInvitation(fromPeerHash, additionalInfo: informationReceived, completion: completion)
        }
    }
}
