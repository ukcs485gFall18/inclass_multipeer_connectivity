//
//  ChatViewController.swift
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//  Followed and made additions to original tutorial by Gabriel Theodoropoulos
//  Swift: http://www.appcoda.com/chat-app-swift-tutorial/
//  Objective C: http://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
//

import UIKit

class ChatViewController: UIViewController {
    
    fileprivate let appDelegate = UIApplication.shared.delegate as! AppDelegate
    fileprivate var messagesToDisplay = [Message]()
    fileprivate var connectedTableView:UITableView!
    var model = ChatModel() //This initialization is replaced by the BrowserView segue preperation
    var isConnected = false

    @IBOutlet weak var roomNameTextField: UITextField!
    @IBOutlet weak var chatTextField: UITextField!
    @IBOutlet weak var chatTable: UITableView!
    @IBOutlet weak var connectedPeersButton: UIButton!
    
    // MARK: IBAction method implementation
    @IBAction func connectedPeersButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: kSegueGotoConnectedUsers, sender: self)
    }
    
    @IBAction func userChangedRoomName(_ sender: Any) {
        
        //User changed room name
        if roomNameTextField.text! != model.getRoomName(){
            model.changeRoomName(roomNameTextField.text!)
            
            //MARK: - HW3: Need to send user a message (shouldn't show on their screen) with the new roomName. Remember, only the owner of a room should be able to change the name of the room. If a Peer is not the owner, the change label should be disabled
        }
    }
    
    
    @IBAction func endChatTapped(_ sender: AnyObject) {
    
        let messageDictionary: [String: String] = [kCommunicationsMessageContentTerm: kCommunicationsEndConnectionTerm]
        let connectedPeers = model.getPeersConnectedTo()
        
        //Just incase no users are connected, but we are stuck here. If no connections valid, need to head back to Browser
        if self.model.getPeersConnectedTo().count == 0{
            
            self.dismiss(animated: true, completion: { () -> Void in
                print("Disconneced from session because no users are connected")
            })
        }
        
        if model.sendData(data: messageDictionary, toPeers: connectedPeers){
            
            //Give some time for connectedPeer to receive disconnect info and properly disconnect themselves
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.model.disconnect()
            })
            
            //Note: Anything called from MultiPeerConnectivity may happen on the background threead. Therefore all UI actions need to happen on the main thread. This can be done using OperationQueue.main.addOperation
            OperationQueue.main.addOperation{ () -> Void in
                self.dismiss(animated: true, completion: { () -> Void in
                print("Disconneced from session")
                })
            }
            
        }else{
            print("Couldn't send diconnect, try again")
        }
        
    }
    
    @IBAction func addPeerButtonTapped(_ sender: Any) {
        //MARK: - HW3: When this button is tapped it should segue (Present as popover) to a new BrowserViewController. In this new view the user can browse for more peers around them and add them to the chat. Note: Only owners should be able to add people to the Chat. If someone is not the owner, they can Browse, but tapping and adding a new user to the chat should be disabled. Hint: this should be similar to when "connectedPeersButtonTapped" is tapped
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handlePeerAddedToRoom(_:)), name: Notification.Name(rawValue: kNotificationChatRefreshRoom), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handlePeerWasLost(_:)), name: Notification.Name(rawValue: kNotificationChatPeerWasLost), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleNewMessagePosted(_:)), name: Notification.Name(rawValue: kNotificationChatNewMessagePosted), object: nil)
        
        
        // Do any additional setup after loading the view.
        chatTable.delegate = self
        chatTable.dataSource = self
        chatTable.estimatedRowHeight = 60.0
        chatTable.rowHeight = UITableView.automaticDimension

        chatTextField.delegate = self
        
        self.hideKeyboardWhenTappedAround()
        
        model.getAllMessagesInRoom(completion: {
            (messagesFound) -> Void in
            
            guard let messages = messagesFound else{
                return
            }
            
            messagesToDisplay = messages
            updateTableview()
        })
        
        roomNameTextField.text = model.getRoomName()
        
        //MARK: - HW3: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
        roomNameTextField.isEnabled = true
        
        setConnectedPeersButton()
        
        if isConnected{
            chatTextField.isEnabled = true
            chatTextField.isHidden = false
        }else{
            chatTextField.isEnabled = false
            chatTextField.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func setConnectedPeersButton(){
        let numberOfConnectedPeers = self.model.getPeersConnectedTo().count
        
        let stringToShow:String!
        
        if numberOfConnectedPeers > 1{
            stringToShow = "\(numberOfConnectedPeers)" + " Peers Connected"
        }else{
            stringToShow = "\(numberOfConnectedPeers)" + " Peer Connected"
        }
    
        OperationQueue.main.addOperation({ () -> Void in
            self.connectedPeersButton.setTitle(stringToShow, for: .normal)
        })
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let viewController = segue.destination as? ConnectedUsersViewController else {
            return
        }
                
        var connectedPeers = [String]()
        //Get the display names for all of the connected users
        for connectedPeerHash in self.model.getPeersConnectedTo(){
            
            if let peerDisplayName = self.model.getPeerDisplayName(connectedPeerHash){
                
                connectedPeers.append(peerDisplayName)
            }
        }
        
        viewController.connectedUsers = connectedPeers
        viewController.delegate = self
    }
    
    //Reload the tableview data and scroll to the bottom using the main thread
    func updateTableview(){
        
        OperationQueue.main.addOperation({ () -> Void in
            self.chatTable.reloadData()
            
            if self.chatTable.contentSize.height > self.chatTable.frame.size.height {
                self.chatTable.scrollToRow(at: IndexPath(row: self.messagesToDisplay.count - 1, section: 0), at: UITableView.ScrollPosition.bottom, animated: true)
            }
        })
    }
    
    func checkIfLastConnection(){
        //If you are the last one in the Chat, leave this room for now
        if self.model.getPeersConnectedTo().count < 2{
            
            //Note: Anything called from MultiPeerConnectivity may happen on the background threead. Therefore all UI actions need to happen on the main thread. This can be done using OperationQueue.main.addOperation
            OperationQueue.main.addOperation({ () -> Void in
                self.dismiss(animated: true, completion: nil)
            })
        }
    }
    
    //MARK: Notification receivers
    @objc func handlePeerAddedToRoom(_ notification: Notification) {
        
        setConnectedPeersButton()
        
        guard let peerAddedHash = notification.userInfo?[kNotificationChatPeerHashKey] as? Int else{
            print("Error in ChatViewController.handlePeerAddedToRoom(). The key \(kNotificationChatPeerHashKey) was not found in the notification")
            return
        }
        
        guard let peerAddedName = model.getPeerDisplayName(peerAddedHash) else{
            return
        }
        
        let alert = UIAlertController(title: "", message: "\(peerAddedName) has been added to the chat", preferredStyle: UIAlertController.Style.alert)
        
        let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
            print("User tapped Okay")
        }
        
        alert.addAction(doneAction)
        
        OperationQueue.main.addOperation({ () -> Void in
           
            //Only segue if this view if the main view
            if self.view.superview != nil {
                self.present(alert, animated: true, completion: nil)
            }
        })
        
    }
    
    @objc func handleNewMessagePosted(_ notification: Notification) {
        
        guard let newMessage = notification.userInfo?[kNotificationChatPeerMessageKey] as? Message else{
            print("Error in ChatViewController.handleNewMessagePosted(). The key \(kNotificationChatPeerMessageKey) was not found in the notification")
            return
        }
        
        messagesToDisplay.append(newMessage)
        
        self.updateTableview()
        
    }
    
    @objc func handlePeerWasLost(_ notification: Notification) {
    
        setConnectedPeersButton()
        
        guard let peerName = notification.userInfo?[kNotificationChatPeerNameKey] as? String else{
            print("Error in ChatViewController.handlePeerWasLost(). The key \(kNotificationChatPeerNameKey) was not found in the notification")
            return
        }
        
        
        let alert = UIAlertController(title: "", message: "\(peerName) left the chat", preferredStyle: UIAlertController.Style.alert)
        
        let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
            
            self.checkIfLastConnection()
        }
        
        alert.addAction(doneAction)
        
        OperationQueue.main.addOperation({ () -> Void in
           
            //Only segue if this view if the main view
            if self.view.superview != nil {
                self.present(alert, animated: true, completion: nil)
            }
        })
    }
    
}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        model.storeNewMessage(content: textField.text!, fromPeer: model.thisUsersPeerUUID(), completion: {
            (messageStored) -> Void in
            
            guard let message = messageStored else{
                return
            }
            
            //MARK: - HW3: This is how you send a meesage. This is a hint for sending the newRoom name to the user. What if you send a similar message with kBrowserPeerRoomName in the key and the value of the newRoomName?
            let messageDictionary: [String: String] = [
                kCommunicationsMessageContentTerm: textField.text!,
                kCommunicationsMessageUUIDTerm: message.uuid
            ]
            
            messagesToDisplay.append(message)
            self.updateTableview()
            
            let roomName = self.model.getRoomName()
            
            OperationQueue.main.addOperation{ () -> Void in
                //MultipeerConnectivity is throwing a copy on main thread warning, which is why we are going to the main thread
                let connectedPeers = self.model.getPeersConnectedTo()
                
                if self.model.sendData(data: messageDictionary, toPeers: connectedPeers){
                    print("Sent message \(message.content) to room \(roomName)")
                }else{
                    print("Couldn't send message \(message.content) to room \(roomName)")
                }
            }
            
        })
        
        //Update text field with nothing
        textField.text = ""
        return true
        
    }
}


// MARK: UITableView related method implementation
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return messagesToDisplay.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "idCell") as! ChatTableViewCell
        
        let message = messagesToDisplay[indexPath.row]
        
        var senderLabelText: String
        var senderColor: UIColor
        
        if message.owner.uuid == model.thisUsersPeerUUID(){
            senderLabelText = "I said"
            senderColor = UIColor.purple
        }else{
            senderLabelText = message.owner.peerName + " said"
            senderColor = UIColor.orange
        }
        
        cell.timeLabel?.text = MPCChatUtility.getRelativeTime(message.createdAt!)
        cell.nameLabel?.text = senderLabelText
        cell.nameLabel?.textColor = senderColor
        cell.messageLabel?.text = message.content
        
        //This is to see the messages from multiple peers in the console, currently there is a viewing issue when multiple peers are connected
        print("Row \(indexPath.row) with message content '\(message.content)'")
        
        return cell
        
    }
}

extension ChatViewController: ConnectedUsersViewControllerDelegate{
    func dismissedView() {
        
        print(self.model.getPeersConnectedTo().count)
        
        //Just incase we received a disconnection while another view is active. If no connections valid, need to head back to Browser
        if self.model.getPeersConnectedTo().count == 0{
            
            let alert = UIAlertController(title: "", message: "All peers have left the room", preferredStyle: UIAlertController.Style.alert)
            
            let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                
                self.dismiss(animated: true, completion: { () -> Void in
                    print("Disconneced from session while user was viewing Connected Users")
                })
            }
            
            alert.addAction(doneAction)

            //Only present if this view if the main view
            if self.view.superview != nil {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
}
