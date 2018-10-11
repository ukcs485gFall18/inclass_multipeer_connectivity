//
//  MPCManager.swift
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//  
//  Followed and made additions & upgrades to original tutorial by Gabriel Theodoropoulos
//  Swift: http://www.appcoda.com/chat-app-swift-tutorial/
//  Objective C: http://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
//  MPC documentation: https://developer.apple.com/documentation/multipeerconnectivity
//

import MultipeerConnectivity


protocol MPCManagerDelegate {
    func foundPeer()
    
    func lostPeer()
    
    func invitationWasReceived(_ fromPeer: String, completion: @escaping (_ fromPeer: String, _ accept: Bool) ->Void)
    
    func connectedWithPeer(_ peerHash: Int)
}


class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    var delegate:MPCManagerDelegate?
    fileprivate var session: MCSession!
    fileprivate var peer: MCPeerID!
    fileprivate var browser: MCNearbyServiceBrowser!
    fileprivate var advertiser: MCNearbyServiceAdvertiser!
    fileprivate var foundPeers = [Int:MCPeerID]()
    fileprivate var isAdvertising = false
    
    var foundPeerHashValues: [Int]{
        get {
            return foundPeers.keys.filter({$0 is Int})
        }
    }
    
    var getIsAdvertising:Bool{
        get {
            return isAdvertising
        }
    }
    
    override init(){
   
        super.init()
        
        //Initialize variables 
        peer = getMCPeerID(UIDevice.current.name)
        
        //If you want to have security, need to create securityIdentity. This is not straight-forward process
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.required)
        session.delegate = self
        
        //The name of your servideType should be unique to your application
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: kAppName)
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        //TODO: When need to add new information to advertiser. Stop it, and reinitialize
        //If you need to include other information when peers are discovered, add it to discoveryInfo
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: kAppName)
        advertiser.delegate = self
        startAdvertising()
    
    }
    
    //MARK: Public methods for delegates
    func stopAdvertising(){
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
    }
    
    func startAdvertising(){
        advertiser.startAdvertisingPeer()
        isAdvertising = true
    }
    
    func invitePeer(_ peerHash: Int){
        
        guard let peerToInvite = foundPeers[peerHash] else{
            return
        }
        
        browser.invitePeer(peerToInvite, to: session, withContext: nil, timeout: 30)
    }
    
    func getPeerDisplayName(_ hash: Int)->String? {
        
        guard let peerID = foundPeers[hash] else{
            return nil
        }
        
        return peerID.displayName
    }
    
    func getPeersConnectedTo()->[Int]{
        
        var connectedPeerHashes = [Int]()
        
        for peer in session.connectedPeers{
            connectedPeerHashes.append(peer.hash)
        }
        
        return connectedPeerHashes
    }
    
    func disconnect(){
        session.disconnect()
    }
    
    func sendData(dictionaryWithData dictionary: Dictionary<String,String>, toPeer peerHash: [Int]) -> Bool {
        
        //This is the data that gets sent to peer
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: dictionary)
        var peersArray = [MCPeerID]()
        
        //Make sure all interested peers are still found
        for hash in peerHash{
            if let peerFound = foundPeers[hash] {
                peersArray.append(peerFound)
            }
        }
        
        do {
            try session.send(dataToSend, toPeers: peersArray, with: MCSessionSendDataMode.reliable)
        }catch let error as NSError {
            
            print(error.localizedDescription)
            self.session.disconnect()
            
            return false
        }
        
        return true
    }
    
    //MARK: Helper method: Note this function is important, should only have one PeerID per device/user so other devices don't get confused during app restarts
    fileprivate func getMCPeerID(_ displayName: String)->MCPeerID?{
        
        let peerIDKey = displayName
        let peerID:MCPeerID!
        
        
        if (UserDefaults.standard.object(forKey: kPeerID) == nil){
            //Create new MCPeerID
            peerID = MCPeerID(displayName: peerIDKey)
            let peerIDDictionary = [peerIDKey:peerID]
            let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerIDDictionary)
            UserDefaults.standard.setValue(peerIDData, forKey: kPeerID)
            UserDefaults.standard.synchronize()
        }else{
            //Get the data available
            guard let peerIDData = UserDefaults.standard.value(forKey: kPeerID) as? Data else{
                print("Error in MPCManager.getMCPeerID(), could not get data from user defaults")
                return nil
            }
            //Turn it into it's dictionary format
            guard let peerIDDictionary = NSKeyedUnarchiver.unarchiveObject(with: peerIDData) as? [String:MCPeerID] else{
                print("Error in MPCManager.getMCPeerID(), could not convert data to the required dictionary format")
                return nil
            }
            //See if the MCPeerID is available for the current UUID
            if peerIDDictionary[peerIDKey] != nil{
                peerID = peerIDDictionary[peerIDKey]!
            }else{
                //Create new MCPeerID if one is not available
                peerID = MCPeerID(displayName: peerIDKey)
                let peerIDDictionary = [peerIDKey:peerID]
                let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerIDDictionary)
                UserDefaults.standard.setValue(peerIDData, forKey: kPeerID)
                UserDefaults.standard.synchronize()
            }
            
        }
        
        return peerID
    }
    
    
    //Delagete methods
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        foundPeers[peerID.hash] = peerID
        delegate?.foundPeer()
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
        foundPeers.removeValue(forKey: peerID.hash)
        
        let messageDictionary: [String: String] = [kCommunicationsMessageTerm: kCommunicationsLostConnectionTerm]
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: messageDictionary)
        let dictionary: [String: Any] = [kCommunicationsDataTerm : dataToSend, kCommunicationsFromPeerTerm: peerID.displayName]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationMPCDisconnetion), object: dictionary)
        
        delegate?.lostPeer()
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print(error.localizedDescription)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping ((Bool, MCSession?) -> Void)) {
        
        //Information user is interested in should be in "withContext" and passed to invitationWasReceived
        delegate?.invitationWasReceived(peerID.displayName, completion: {
            (fromPeer, accept) -> Void in
            
            if self.session.connectedPeers.count < kMCSessionMaximumNumberOfPeers{
                
                print("I'm accepting(\(accept)) \(fromPeer)'s invitation to connect to session \(String(describing: self.session))")
                invitationHandler(accept, self.session)
            }else{
                print("Warning: Not accepting invite from peer \(fromPeer) reached max session peers allowed(\(kMCSessionMaximumNumberOfPeers))")
                invitationHandler(false, self.session)
            }
        })
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        isAdvertising = false
        print(error.localizedDescription)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state{
        case .connected:
            print("Connected to session: \(session)")
            delegate?.connectedWithPeer(peerID.hash)
            
        case .connecting:
            print("Connecting to session \(session)")
            
        case .notConnected:
            print("Not connected to session \(session)")
            let messageDictionary: [String: String] = [kCommunicationsMessageTerm: kCommunicationsLostConnectionTerm]
            let dataToSend = NSKeyedArchiver.archivedData(withRootObject: messageDictionary)
            let dictionary: [String: Any] = [kCommunicationsDataTerm : dataToSend, kCommunicationsFromPeerTerm: peerID.displayName]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationMPCDataReceived), object: dictionary)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    
        //DO NOT remove the following lines, they are needed to receive Messages from peer
        let dictionary: [String: Any] = [
            kCommunicationsDataTerm: data,
            kCommunicationsFromPeerTerm: peerID.displayName
        ]
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationMPCDataReceived), object: dictionary)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    //If you implement security, you will need to authenticate certificates here
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping ((Bool) -> Void)) {
       
        //DO NOT Remove this line. Ommitting will not allow MPC to connect
        certificateHandler(true)
    }
    
}
