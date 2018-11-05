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
    
    func foundPeer(_ peerHash: Int, withInfo: [String: String]?)
    
    func lostPeer(_ peerHash: Int)
    
    func invitationWasReceived(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void)
    
    func connectedWithPeer(_ peerHash: Int, peerName: String)
    
}

protocol MPCManagerMessageDelegate {
    
    func messageReceived(_ fromPeerHash:Int, data: Data)
    
    func lostPeer(_ peerHash: Int, peerName: String)
}

class MPCManager: NSObject {
    
    var managerDelegate:MPCManagerDelegate?
    var messageDelegate:MPCManagerMessageDelegate?
    fileprivate var session: MCSession!
    fileprivate var myPeer: MCPeerID!
    fileprivate var browser: MCNearbyServiceBrowser!
    fileprivate var advertiser: MCNearbyServiceAdvertiser!
    fileprivate var foundPeers = [Int:MCPeerID]()
    fileprivate var isAdvertising = false
    fileprivate var myServiceType:String!
    fileprivate var myAdvertisingName:String!
    fileprivate var myDiscoveryInfo:[String:String]?
    
    var getIsAdvertising:Bool{
        get {
            return isAdvertising
        }
    }
    
    //Don't call, won't start up MPC
    override init() {
        super.init()
    }
    
    convenience init(_ serviceType: String, advertisingName: String, discoveryInfo: [String:String]) {
        
        self.init()
        myServiceType = serviceType
        myAdvertisingName = advertisingName
        myDiscoveryInfo = discoveryInfo
        
        //Initialize variables
        myPeer = getMCPeerID(advertisingName)
        
        //If you want to have security, need to create securityIdentity. This is not straight-forward process
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.required)
        session.delegate = self
        
        //The name of your serviceType should be unique to your application
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: myServiceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        /*
         Hint: When you need to add new information to advertiser. Stop it, and reinitialize. If you need to include other information when peers are discovered, add it to discoveryInfo
         */
        advertiser = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: myDiscoveryInfo, serviceType: myServiceType)
        advertiser.delegate = self
        startAdvertising()
        
        //Notify everyone MPC is up and running
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationMPCIsInitialized), object: nil)
    }
    
    //MARK: Public methods for managerDelegates
    func stopAdvertising(){
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
    }
    
    func startAdvertising(){
        advertiser.startAdvertisingPeer()
        isAdvertising = true
    }
    
    func invitePeer(_ peerHash: Int, additionalInfo: [String:Any]?){
        
        guard let peerToInvite = foundPeers[peerHash] else{
            print("Error in MPCManager.invitePeer(). Peer \(peerHash) is no longer found")
            return
        }
        
        guard let info = additionalInfo else{
            print("Error in MPCManager.invitePeer(). No additionalInfo used to connect to \(peerHash)")
            return
        }
        
        let infoAsData = NSKeyedArchiver.archivedData(withRootObject: info)
        
        browser.invitePeer(peerToInvite, to: session, withContext: infoAsData, timeout: 30)
    }
    
    func getPeerDisplayName(_ hash: Int)->String? {
        
        guard let peerID = foundPeers[hash] else{
            print("Error in MPCManager.getPeerDisplayName(). Peer \(hash) no longer available")

            return nil
        }
        
        return peerID.displayName
    }
    
    func getPeersConnectedTo()->[Int]{
        
        var connectedpeerHashs = [Int]()
        
        for peer in session.connectedPeers{
            connectedpeerHashs.append(peer.hash)
        }
        
        return connectedpeerHashs
    }
    
    func disconnect(){
        session.disconnect()
    }
    
    func sendData(dictionaryWithData dictionary: Dictionary<String,String>, toPeers peerHashs: [Int]) -> Bool {
        
        //Prepare to send to all interested peers who are still connected
        var peersConnected = [MCPeerID]()
        for hash in peerHashs{
            if let peerFound = foundPeers[hash] {
                peersConnected.append(peerFound)
            }
        }
        
        //This is the data that gets sent to peer
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: dictionary)
        
        do {
            
            try session.send(dataToSend, toPeers: peersConnected, with: .reliable)
            
        }catch {
            
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

}

extension MPCManager: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        switch state{
        case .connected:
            print("Connected to \(peerID.displayName) with hash \(peerID.hash) in session \(session)")
            managerDelegate?.connectedWithPeer(peerID.hash, peerName: peerID.displayName)
            
        case .connecting:
            print("Connecting to \(peerID.displayName) with hash \(peerID.hash) in session \(session)")
            
            
        case .notConnected:
            print("Not connected to \(peerID.displayName) with hash \(peerID.hash) in session  \(session)")
            
            messageDelegate?.lostPeer(peerID.hash, peerName: peerID.displayName)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        //DO NOT remove the following lines, they are needed to receive Messages from peer
        messageDelegate?.messageReceived(peerID.hash, data: data)
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

extension MPCManager: MCNearbyServiceBrowserDelegate {
    //Delagete methods
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        foundPeers[peerID.hash] = peerID
        managerDelegate?.foundPeer(peerID.hash, withInfo: info)
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
        foundPeers.removeValue(forKey: peerID.hash)
        messageDelegate?.lostPeer(peerID.hash, peerName: peerID.displayName)
        managerDelegate?.lostPeer(peerID.hash)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print(error.localizedDescription)
    }

}

extension MPCManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping ((Bool, MCSession?) -> Void)) {
        
        //Information user is interested in should be in "withContext" and passed to invitationWasReceived
        guard let additionalInformation = NSKeyedUnarchiver.unarchiveObject(with: context!) as? [String:Any] else{
            print("Error in MPCManager.advertisor Could not unarchive context information with additionalInformation")
            invitationHandler(false, self.session)
            return
        }
        
        managerDelegate?.invitationWasReceived(peerID.hash, additionalInfo: additionalInformation, completion: {
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
}
