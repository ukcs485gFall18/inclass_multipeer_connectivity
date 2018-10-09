//
//  MPCManager.swift
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//  
//  Followed and made additions to original tutorial by Gabriel Theodoropoulos
//  Swift: http://www.appcoda.com/chat-app-swift-tutorial/
//  Objective C: http://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
//  MPC documentation: https://developer.apple.com/documentation/multipeerconnectivity
//

import MultipeerConnectivity


protocol MPCManagerDelegate {
    func foundPeer()
    
    func lostPeer()
    
    func invitationWasReceived(_ fromPeer: String, completion: @escaping (_ fromPeer: String, _ accept: Bool) ->Void)
    
    func connectedWithPeer(_ peerID: MCPeerID)
}


class MPCManager: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    
    var delegate:MPCManagerDelegate?
    var session: MCSession!
    var peer: MCPeerID!
    var browser: MCNearbyServiceBrowser!
    var advertiser: MCNearbyServiceAdvertiser!
    var foundPeers = [MCPeerID]()
    
    
    override init(){
   
        super.init()
        
        //Initialize variables 
        peer = MCPeerID(displayName: UIDevice.current.name)
        //session = MCSession(peer: peer, securityIdentity: [myIdentity], encryptionPreference: MCEncryptionPreference.Required)
        session = MCSession(peer: peer)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: kAppName)
        browser.delegate = self
        
        //TODO: When need to add new information to advertiser. Stop it, and reinitialize
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: kAppName)
        advertiser.delegate = self
    
    }
    
    //Delagete methods
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        var peerAlreadyInBrowser = false
        
        //TODO: All discover information for a specific peer will be here. Need to pass it to the foundPeer delegate
        //TODO LATER: Implement faster search function to find peers and remove
        for (index, aPeer) in foundPeers.enumerated()
        {
            if aPeer == peerID{
                foundPeers.insert(peerID, at: index)
                peerAlreadyInBrowser = true
                break
            }
        }
        
        if !peerAlreadyInBrowser{
            foundPeers.append(peerID)
        }
        
        delegate?.foundPeer()
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        for (index, aPeer) in foundPeers.enumerated()
        {
            if aPeer == peerID{
                foundPeers.remove(at: index)
               
                let messageDictionary: [String: String] = [kCommunicationsMessageTerm: kCommunicationsLostConnectionTerm]
                let dataToSend = NSKeyedArchiver.archivedData(withRootObject: messageDictionary)
                let dictionary: [String: Any] = [kCommunicationsDataTerm : dataToSend, kCommunicationsFromPeerTerm: aPeer]
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "receivedMPCDisconnectionNotification"), object: dictionary)
                break
            }
        }
        
        delegate?.lostPeer()
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print(error.localizedDescription)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping ((Bool, MCSession?) -> Void)) {
        
        //self.invitationHandler = invitationHandler
        
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
        print(error.localizedDescription)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state{
        case .connected:
            print("Connected to session: \(session)")
            delegate?.connectedWithPeer(peerID)
            
        case .connecting:
            print("Connecting to session \(session)")
            
        case .notConnected:
            print("Not connected to session \(session)")
            let messageDictionary: [String: String] = [kCommunicationsMessageTerm: kCommunicationsLostConnectionTerm]
            let dataToSend = NSKeyedArchiver.archivedData(withRootObject: messageDictionary)
            let dictionary: [String: Any] = [kCommunicationsDataTerm : dataToSend, kCommunicationsFromPeerTerm: peerID]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "receivedMPCChatDataNotification"), object: dictionary)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    
        //REMEMBER: Do not remove the following lines, they are needed to receive Messages from peer
        let dictionary: [String: Any] = [
            kCommunicationsDataTerm: data,
            kCommunicationsFromPeerTerm: peerID]
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "receivedMPCChatDataNotification"), object: dictionary)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping ((Bool) -> Void)) {
       
        //This is needed if certificates are not implement. Ommitting will not allow MPC to connect
        certificateHandler(true)
    }
    
    
    func sendData(dictionaryWithData dictionary: Dictionary<String,String>, toPeer targetPeer: MCPeerID) -> Bool {
        
        //This is the data that gets sent to peer
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: dictionary)
        let peersArray = [targetPeer]
        
        do {
            try session.send(dataToSend, toPeers: peersArray, with: MCSessionSendDataMode.reliable)
        }catch let error as NSError {
            
            print(error.localizedDescription)
            return false
        }
        
        return true
    }
    
}
