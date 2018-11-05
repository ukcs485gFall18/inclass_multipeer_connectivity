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
    let peersSeenBefore = [Int:Peer]()
    var roomToJoin:Room?
    var peerUUIDHash = [String:Int]()
    
    @IBOutlet weak var tblPeers: UITableView!
    @IBOutlet weak var browserSegment: UISegmentedControl!
    @IBAction func browserSegmentChanged(_ sender: Any) {
        tblPeers.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(BrowserViewController.handleCoreDataInitializedReceived(_:)), name: Notification.Name(rawValue: kNotificationCoreDataInitialized), object: nil)
        
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
    
    @objc func handleCoreDataInitializedReceived(_ notification: NSNotification) {
        
        tblPeers.reloadData() //Reload cells to reflect coreData
    }
    
    @objc func handleBrowserUserTappedCell(_ notification: NSNotification) {
        // Note: use notification.object if you want to send any data with a posted Notification
        let receivedDataDictionary = notification.object as! [String: Any]
        
        guard let peerUUID = receivedDataDictionary[kBrowserpeerUUIDTerm] as? String else{
            print("Error in BrowserViewController.handleBrowserUserTappedCell(). peerUUID not found")
            return
        }
        
        guard let peerHash = peerUUIDHash[peerUUID] else{
            return
        }
        
        guard let peerDisplayName = appDelagate.mpcManager.getPeerDisplayName(peerHash) else{
            return
        }
        
        let roomName = "Chat w/ \(peerDisplayName)"
        
        let actionSheet = UIAlertController(title: "", message: "Connect to \(peerDisplayName)", preferredStyle: UIAlertController.Style.actionSheet)
        
        let actionTitle = "Connect to \(peerDisplayName)"
        
        let connectAction: UIAlertAction = UIAlertAction(title: actionTitle, style: UIAlertAction.Style.default) { (alertAction) -> Void in
            
            self.model.createNewChatRoom(peerUUID, roomName: roomName, completion: {
                (createdRoom) -> Void in
                
                guard let room = createdRoom else{
                    return
                }
                
                self.roomToJoin = room
                
                //Build invite information to send to user
                let info = [
                    kBrowserPeerRoomUUID: room.uuid,
                    kBrowserPeerRoomName: roomName
                ]
                
                //This method is used to send peer info they should used to connect
                self.appDelagate.mpcManager.invitePeer(peerHash, additionalInfo: info)
                
            })
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(connectAction)
        actionSheet.addAction(cancelAction)
        //ToDo: Need to allow the user to add to a previous created room, Need to query for the room and .addAction for each room here
        
        self.present(actionSheet, animated: true, completion: nil)
        
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
            
            let viewController = segue.destination as! ChatViewController
            
            viewController.room = roomToJoin
            viewController.model = ChatModel(peerUUIDHashDictionary: model.peerUUIDHash, peerHashUUIDDictionary: model.peerHashUUID)
            viewController.isConnected = true
        }
    }
    
}

// MARK: MPCManager delegate methods implementation
extension BrowserViewController: MPCManagerDelegate{
    
    //ToDo: Fix BrowserTable refreshing/reloading when MPC Manager refreshes and "Peers" is the segment selected
    func foundPeer(_ peerHash: Int, withInfo: [String:String]?) {
        
        model.foundPeer(peerHash, info: withInfo)
        
        tblPeers.reloadData()
    }
    
    func lostPeer(_ peerHash: Int) {
        
        model.lostPeer(peerHash)
        tblPeers.reloadData()
    }
    
    func invitationWasReceived(_ fromPeerHash: Int, additionalInfo: [String: Any], completion: @escaping (_ fromPeer: Int, _ accept: Bool) ->Void) {
        
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
                    self.roomToJoin = roomFound!
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
            (stored) -> Void in
            
            if stored{
                OperationQueue.main.addOperation{ () -> Void in
                    self.performSegue(withIdentifier: kSegueChat, sender: self)
                }
            }else{
                print("Couldn't store peer info, disconnecting from \(peerName) with uuid \(peerUUID)")
                appDelagate.mpcManager.disconnect()
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
        //ToDo: One of these need to be changed show correct table count based on the segment selection
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
            cell.lastSeenLabel?.text = lastSeenPeer.description
            
            guard let lastConnectedPeer = lastConnected else{
                cell.lastConnectedLabel?.text = "N/A"
                return
            }
            
            cell.lastConnectedLabel?.text = lastConnectedPeer.description
            
        })
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
}


