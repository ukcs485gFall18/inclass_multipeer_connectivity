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
        case 1: //This segment should list Peers that the user has connected to before, but only the ones who are currently found on browser. If you are around a 100 peers, but only want to see the ones you know. Should sort by lastTimeConnected. The logistics should be carried out in the BrowserModel
            tblPeers.reloadData()
        case 2: //This should list all if the chats you have been in before and be sorted from modifiedAt. When a user selects a particular chat, it should segue to ChatViewController and display all of the messages. Since the user is not connected at this time, isConnected should be false, and the user should not be able to add any new data to the chat
            tblPeers.reloadData()
        default:
            tblPeers.reloadData()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view

        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleScreenNeedsToBeRefreshed(_:)), name: Notification.Name(rawValue: kNotificationCoreDataIsReady), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleScreenNeedsToBeRefreshed(_:)), name: Notification.Name(rawValue: kNotificationBrowserScreenNeedsToBeRefreshed), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleSegueToChatRoom(_:)), name: Notification.Name(rawValue: kNotificationBrowserConnectedToFirstPeer), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleBrowserUserTappedCell(_:)), name: Notification.Name(rawValue: kNotificationBrowserUserTappedCell), object: nil)
        
        model.setMPCInvitationManagerDelegate(self)
        
        tblPeers.delegate = self
        tblPeers.dataSource = self
        
        browserSegment.selectedSegmentIndex = 0 //Default segment to first index
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tblPeers.reloadData()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleSegueToChatRoom(_ notification: Notification) {
        
        OperationQueue.main.addOperation{ () -> Void in
            //Only segue if this view if the main view
            if self.view.superview != nil {
                self.performSegue(withIdentifier: kSegueChat, sender: self)
            }
        }
    }
    
    @objc func handleScreenNeedsToBeRefreshed(_ notification: Notification) {
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
        
        guard let peerDisplayName = model.getPeerDisplayName(peerHash) else{
            return
        }
        
        
        
        model.findOldChatRooms(peerToJoinUUID: peerUUID, completion: {
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
                            self.model.invitePeer(peerHash, info: info)
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
                
                self.model.createNewChatRoom(peerUUID, roomName: roomName, completion: {
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
                        self.model.invitePeer(peerHash, info: info)
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
                
                //Got popover code from https://medium.com/@nickmeehan/actionsheet-popover-on-ipad-in-swift-5768dfa82094
                if let popoverController = actionSheet.popoverPresentationController{
                    
                    popoverController.sourceView = self.view
                    popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                
                self.present(actionSheet, animated: true, completion: nil)
            }
            
        })
        
    }
    
    // MARK: IBAction method implementation
    
    @IBAction func startStopAdvertising(_ sender: AnyObject) {
        let actionSheet = UIAlertController(title: "", message: "Change Visibility", preferredStyle: UIAlertController.Style.actionSheet)
        
        var actionTitle: String
        let isAdvertising = model.getIsAdvertising()
        
        if isAdvertising == true {
            actionTitle = "Make me invisible to others"
        }else {
            
            actionTitle = "Make me visible to others"
        }
        
        let visibilityAction: UIAlertAction = UIAlertAction(title: actionTitle, style: UIAlertAction.Style.default) { (alertAction) -> Void in
            if isAdvertising == true {
                self.model.stopAdvertising()
            }else {
                self.model.startAdvertising()
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
            
            guard let _ = model.roomToJoin else{
                fatalError("Never set the room for segue, should never happen")
            }
            
            viewController.model = ChatModel(browserModel: model)
            //viewController.model = ChatModel(peer: model.getPeer, peerUUIDHashDictionary: model.getPeerUUIDHashDictionary, peerHashUUIDDictionary: model.getPeerHashUUIDDictionary, room: room)
            viewController.isConnected = true
        }
    }
    
}

// MARK: MPCManager delegate methods implementation
extension BrowserViewController: MPCManagerInvitationDelegate{
    
    func invitationWasReceived(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void) {
        
        //If the user is connected to anyone, deny all invitations received
        if model.getPeersConnectedTo().count > 0{
            completion(fromPeerHash, false)
        }
        
        guard let roomUUID = additionalInfo[kBrowserPeerRoomUUID] as? String else{
            return
        }
        
        guard let roomName = additionalInfo[kBrowserPeerRoomName] as? String else {
            return
        }
        
        guard let fromPeerName = model.getPeerDisplayName(fromPeerHash) else{
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
    
}

// MARK: UITableView related method implementation
extension BrowserViewController: UITableViewDelegate, UITableViewDataSource{
    
    //HW3: Fix BrowserTable refreshing/reloading when MPC Manager refreshes and "Peers" is the segment selected
    
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
        
        guard let displayName = model.getPeerDisplayName(peerHash) else{
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
