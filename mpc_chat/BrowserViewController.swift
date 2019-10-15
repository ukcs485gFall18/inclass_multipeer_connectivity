//
//  BrowserViewController.swift
//  
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//  Followed and made additions to original tutorial by Gabriel Theodoropoulos
//  Swift: http://www.appcoda.com/chat-app-swift-tutorial/
//  Objective C: http://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
//

import UIKit

class BrowserViewController: UIViewController {
    
    let appDelagate = UIApplication.shared.delegate as! AppDelegate
    let model = BrowserModel()
    
    @IBOutlet weak var tblPeers: UITableView!
    @IBOutlet weak var browserSegment: UISegmentedControl!
    
    @IBAction func browserSegmentChanged(_ sender: Any) {
        
        //HW3: Need to write code to handle when this segment changes. Descriptions are below
        switch browserSegment.selectedSegmentIndex {
        case 0: //This is the original browser, already works correctly
            tblPeers.reloadData()
        case 1: //This segment to show Peers that the user has connected to before, but only the ones who are currently fund on browser. If you are around a 100 peers, but only want to see the ones you know. Should sort by lastTimeConnected. The work should be done in the BrowserModel
            tblPeers.reloadData()
        case 2: //This should list all if the chats you have been in before and be sorted from modifiedAt. When a user selects a particular chat, it should segue to ChatViewController and display all of the messages. Since the user is not connected at this time, isConnected should be false, and the user should not be able to add any new data to the chat
            tblPeers.reloadData()
        default:
            tblPeers.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleCoreDataInitializedReceived(_:)), name: Notification.Name(rawValue: kNotificationCoreDataIsReady), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleBrowserUserTappedCell(_:)), name: Notification.Name(rawValue: kNotificationBrowserUserTappedCell), object: nil)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view
        
        tblPeers.delegate = self
        tblPeers.dataSource = self
        
        appDelagate.mpcManager.managerDelegate = self
        browserSegment.selectedSegmentIndex = 0 //Default segment to first index
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleCoreDataInitializedReceived(_ notification: Notification) {
        //Reload cells to reflect coreData updates
        tblPeers.reloadData()
    }
    
    @objc func handleBrowserUserTappedCell(_ notification: Notification) {
        
        // Note: use notification.object if you want to send any data with a posted Notification
        let receivedDataDictionary = notification.object as! [String: Any]
        
        guard let peerUUID = receivedDataDictionary[kBrowserPeerUUIDTerm] as? String else{
            print("Error in BrowserViewController.handleBrowserUserTappedCell(). peerUUID not found")
            return
        }
        
        guard let peerHash = model.getPeerHashFromUUID(peerUUID) else{
            return
        }
        
        guard let peerDisplayName = appDelagate.mpcManager.getPeerDisplayName(peerHash) else{
            return
        }
        
        model.findOldChatRooms(self.appDelagate.peerUUID, peerToJoinUUID: peerUUID, completion: {
            (oldRoomsFound)-> Void in
            
            var oldRoomActions = [UIAlertAction]()
            
            //Need too add all rooms, will limit to last 3 for readability
            if oldRoomsFound != nil{
                
                for (index,room) in oldRoomsFound!.enumerated(){
                    
                    let actionTitle = "Join \(room.name)"
                    
                    let createOldRoomAction: UIAlertAction = UIAlertAction(title: actionTitle, style: UIAlertAction.Style.default) {
                        (alertAction) -> Void in
                        
                        self.model.roomToJoin = room //Set the room to join to help preperation of segue
                        
                        //Build invite information to send to user
                        let info = [
                            kBrowserPeerRoomUUID: room.uuid,
                            kBrowserPeerRoomName: room.name
                        ]
                        
                        OperationQueue.main.addOperation{ () -> Void in
                            //This method is used to send peer info they should used to connect
                            self.appDelagate.mpcManager.invitePeer(peerHash, additionalInfo: info)
                        }
                    }
                    
                    oldRoomActions.append(createOldRoomAction)
                    
                    //Limiting to first 3 for readability
                    if index == 2{
                        break
                    }
                }
            }
            
            let roomName = "Chat w/ \(peerDisplayName)" //Probably want to come up with better default room name
            
            let actionSheet = UIAlertController(title: "", message: "Connect to \(peerDisplayName)", preferredStyle: UIAlertController.Style.actionSheet)
            
            let actionNewRoomTitle = "Create New \(roomName)"
            let createNewRoomAction: UIAlertAction = UIAlertAction(title: actionNewRoomTitle, style: UIAlertAction.Style.default) { (alertAction) -> Void in
                
                self.model.createNewChatRoom(self.appDelagate.peerUUID, peerToJoinUUID: peerUUID, roomName: roomName, completion: {
                    (createdRoom) -> Void in
                    
                    guard let room = createdRoom else{
                        return
                    }
                    
                    self.model.roomToJoin = room
                    
                    //Build invite information to send to user
                    let info = [
                        kBrowserPeerRoomUUID: room.uuid,
                        kBrowserPeerRoomName: roomName
                    ]
                    
                    OperationQueue.main.addOperation{ () -> Void in
                        //This method is used to send peer info they should used to connect
                        self.appDelagate.mpcManager.invitePeer(peerHash, additionalInfo: info)
                    }
                    
                })
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { (alertAction) -> Void in
                
            }
            
            actionSheet.addAction(createNewRoomAction)
            //Add all old actions before cancel
            for action in oldRoomActions{
                actionSheet.addAction(action)
            }
            actionSheet.addAction(cancelAction)
            
            OperationQueue.main.addOperation{ () -> Void in
                self.present(actionSheet, animated: true, completion: nil)
            }
            
        })
        
    }
    
    // MARK: IBAction method implementation
    
    @IBAction func startStopAdvertising(_ sender: AnyObject) {
        let actionSheet = UIAlertController(title: "", message: "Change Visibility", preferredStyle: UIAlertController.Style.actionSheet)
        
        var actionTitle: String
        let isAdvertising = appDelagate.mpcManager.getIsAdvertising
        
        if isAdvertising == true {
            actionTitle = "Make me invisible to others"
        }else {
            
            actionTitle = "Make me visible to others"
        }
        
        let visibilityAction: UIAlertAction = UIAlertAction(title: actionTitle, style: UIAlertAction.Style.default) { (alertAction) -> Void in
            if isAdvertising == true {
                self.appDelagate.mpcManager.stopAdvertising()
            }else {
                self.appDelagate.mpcManager.startAdvertising()
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(visibilityAction)
        actionSheet.addAction(cancelAction)
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == kSegueChat) {
            
            //Prepare the upcoming view with all of the necessary info
            let viewController = segue.destination as! ChatViewController
            
            guard let room = model.roomToJoin else{
                fatalError("Never set the room for segue, should never happen")
            }
            
            viewController.model = ChatModel(peer: model.getPeer, peerUUIDHashDictionary: model.getPeerUUIDHashDictionary, peerHashUUIDDictionary: model.getPeerHashUUIDDictionary, room: room)
            viewController.isConnected = true
        }
    }
    
}

// MARK: MPCManager delegate methods implementation
extension BrowserViewController: MPCManagerDelegate{
    
    //HW3: Fix BrowserTable refreshing/reloading when MPC Manager refreshes and "Peers" is the segment selected
    func foundPeer(_ peerHash: Int, withInfo: [String:String]?) {
        
        model.foundPeer(peerHash, info: withInfo)
        
        tblPeers.reloadData()
    }
    
    func lostPeer(_ peerHash: Int) {
        
        model.lostPeer(peerHash)
        tblPeers.reloadData()
    }
    
    func invitationWasReceived(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void) {
        
        //If the user is connected to anyone, deny all invitations received
        if appDelagate.mpcManager.getPeersConnectedTo().count > 0{
            completion(fromPeerHash, false)
        
        }
        
        guard let roomUUID = additionalInfo[kBrowserPeerRoomUUID] as? String else{
            return
        }
        
        guard let roomName = additionalInfo[kBrowserPeerRoomName] as? String else {
            return
        }
        
        guard let fromPeerName = appDelagate.mpcManager.getPeerDisplayName(fromPeerHash) else{
            return
        }
        
        guard let fromPeerUUID = model.getPeerUUIDFromHash(fromPeerHash) else{
            return
        }
        
        let alert = UIAlertController(title: "", message: "\(fromPeerName) wants you to join \(roomName).", preferredStyle: UIAlertController.Style.alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertAction.Style.default)  {(alertAction) -> Void in
            
            self.model.joinChatRoom(roomUUID, roomName: roomName, ownerUUID: fromPeerUUID, ownerName: fromPeerName, completion: {
                (roomFound) -> Void in
                
                if roomFound != nil{
                    self.model.roomToJoin = roomFound!
                    completion(fromPeerHash, true)
                }else{
                    print("Couldn't create room in CoreData")
                    completion(fromPeerHash, false)
                }
                
            })
            
        }
        
        let declineAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {(alertAction) -> Void in
            completion(fromPeerHash, false)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        OperationQueue.main.addOperation{ () -> Void in
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    func connectedWithPeer(_ peerHash: Int, peerName: String) {
        
        guard let peerUUID = model.getPeerUUIDFromHash(peerHash) else{
            return
        }
        
        model.storeNewPeer(peerUUID: peerUUID, peerName: peerName, isConnectedToPeer: true, completion: {
            (storedPeer) -> Void in
            
            if storedPeer == nil{
                print("Couldn't store peer info, disconnecting from \(peerName) with uuid \(peerUUID)")
                appDelagate.mpcManager.disconnect()
                
            }else{
                
                OperationQueue.main.addOperation{ () -> Void in
                    //Only segue if this view if the main view
                    if self.view.superview != nil {
                        self.performSegue(withIdentifier: kSegueChat, sender: self)
                    }
                }
            }
        })
    }
}

// MARK: UITableView related method implementation
extension BrowserViewController: UITableViewDelegate, UITableViewDataSource{
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //HW3: One of these need to be changed show correct table count based on the segment selection
        switch browserSegment.selectedSegmentIndex {
        case 0:
            return model.getPeersFoundUUIDs.count
        case 1:
            return model.getPeersFoundUUIDs.count
        case 2:
            return model.getPeersFoundUUIDs.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "idCellPeer") as! BrowserTableViewCell
        
        //Store peerUUID for Cell
        cell.peerUUID = model.getPeersFoundUUIDs[indexPath.row]
        
        guard let peerHash = model.getPeerHashFromUUID(cell.peerUUID) else{
            return cell
        }
        
        guard let displayName = appDelagate.mpcManager.getPeerDisplayName(peerHash) else{
            return cell
        }
        
        cell.peerNameLabel?.text = displayName
    
        model.lastTimeSeenPeer(cell.peerUUID, completion: {
            (lastSeen, lastConnected) -> Void in
            
            guard let lastSeenPeer = lastSeen else{
                //If we've never seen, then we never connected before
                cell.isPeerLabel?.text = "Unknown"
                cell.lastConnectedLabel?.text = "N/A"
                cell.lastSeenLabel?.text = "N/A"
                
                return
            }
            
            cell.isPeerLabel?.text = "Peer"
            cell.lastSeenLabel?.text = MPCChatUtility.getRelativeTime(lastSeenPeer)
            
            guard let lastConnectedPeer = lastConnected else{
                cell.lastConnectedLabel?.text = "N/A"
                return
            }
            
            cell.lastConnectedLabel?.text = MPCChatUtility.getRelativeTime(lastConnectedPeer)
            
        })
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
}
