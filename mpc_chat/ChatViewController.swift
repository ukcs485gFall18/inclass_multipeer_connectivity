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
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var messagesToDisplay = [Message]()
    var model = ChatModel() //This initialization is replaced by the BrowserView segue preperation
    var isConnected = false
    var connectedTableView:UITableView!

    @IBOutlet weak var roomNameTextField: UITextField!
    @IBOutlet weak var chatTextField: UITextField!
    @IBOutlet weak var chatTable: UITableView!
    @IBOutlet weak var connectedPeersButton: UIButton!
    
    //HW3: Need to add a button the storyboard that when tapped, opens a subView or openning to BrowserViewController. Here the user keep see more peers around and add them to the chat. Note: Only owners should be able to add people to the Chat. If someone is not the owner, they can Browse, but tapping and adding a new user to the chat should be disabled
    
    @IBAction func connectedPeersButtonTapped(_ sender: Any) {
        
        if self.view.subviews.last == connectedTableView{
            self.view.subviews.last?.removeFromSuperview()
        }else{
            self.view.addSubview(connectedTableView)
        }
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handlePeerAddedToRoom(_:)), name: Notification.Name(rawValue: kNotificationChatRefreshRoom), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handlePeerWasLost(_:)), name: Notification.Name(rawValue: kNotificationChatPeerWasLost), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleNewMessagePosted(_:)), name: Notification.Name(rawValue: kNotificationChatNewMessagePosted), object: nil)
        
        
        // Do any additional setup after loading the view.
        let connectedFrame = CGRect(x: 50,y: 400,width: 320,height: 200)
        connectedTableView = UITableView(frame: connectedFrame)
        connectedTableView.delegate = self
        connectedTableView.dataSource = self
        connectedTableView.register(UITableViewCell.self, forCellReuseIdentifier: "idCellConnected")
        
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
        
        //HW3: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
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
    
    func setConnectedPeersButton(){
        let numberOfConnectedPeers = self.model.curentBrowserModel.getPeersConnectedTo().count
        
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
    
    
    @IBAction func userChangedRoomName(_ sender: Any) {
        
        //User changed room name
        if roomNameTextField.text! != model.getRoomName(){
            model.changeRoomName(roomNameTextField.text!)
            
            //HW3: Need to send user a message (shouldn't show on their screen) with the new roomName. Remember, only the owner of a room should be able to change the name of the room. If a Peer is not the owner, the change label should be disabled
        }
    }
    
    // MARK: IBAction method implementation
    @IBAction func endChat(_ sender: AnyObject) {
    
        let messageDictionary: [String: String] = [kCommunicationsMessageContentTerm: kCommunicationsEndConnectionTerm]
        let connectedPeers = model.curentBrowserModel.getPeersConnectedTo()
        
        if model.curentBrowserModel.sendData(dictionaryWithData: messageDictionary, toPeers: connectedPeers){
            
            //Give some time for connectedPeer to receive disconnect info
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                self.model.curentBrowserModel.disconnect()
            })
            
            self.dismiss(animated: true, completion: { () -> Void in
                print("Disconneced from session")
            })
            
        }else{
            print("Couldn't send diconnect, try again")
        }
        
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
        if self.model.curentBrowserModel.getPeersConnectedTo().count < 2{
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
        
        guard let peerAddedName = model.curentBrowserModel.getPeerDisplayName(peerAddedHash) else{
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
        
        model.storeNewMessage(content: textField.text!, fromPeer: model.curentBrowserModel.peerUUID, completion: {
            (messageStored) -> Void in
            
            guard let message = messageStored else{
                return
            }
            
            //HW3: This is how you send a meesage. This is a hint for sending the newRoom name to the user. What if you send a similar message with kBrowserPeerRoomName in the key and the value of the newRoomName?
            let messageDictionary: [String: String] = [
                kCommunicationsMessageContentTerm: textField.text!,
                kCommunicationsMessageUUIDTerm: message.uuid
            ]
            
            messagesToDisplay.append(message)
            self.updateTableview()
            
            let roomName = self.model.getRoomName()
            
            OperationQueue.main.addOperation{ () -> Void in
                //MultipeerConnectivity is throwing a copy on main thread warning, which is why we are going to the main thread
                let connectedPeers = self.model.curentBrowserModel.getPeersConnectedTo()
                
                if self.model.curentBrowserModel.sendData(dictionaryWithData: messageDictionary, toPeers: connectedPeers){
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
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if tableView == chatTable{
            return messagesToDisplay.count
        }else{
            return self.model.curentBrowserModel.getPeersConnectedTo().count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if tableView == chatTable{
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "idCell") as! ChatTableViewCell
            
            let message = messagesToDisplay[indexPath.row]
            
            var senderLabelText: String
            var senderColor: UIColor
            
            if message.owner.uuid == model.curentBrowserModel.peerUUID{
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
        }else{
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "idCellConnected")!
            
            cell.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            cell.alpha=0.5
            
            let connectedPeerHash = self.model.curentBrowserModel.getPeersConnectedTo()[indexPath.row]
            
            if let peerDisplayName = self.model.curentBrowserModel.getPeerDisplayName(connectedPeerHash){
                cell.textLabel?.text = peerDisplayName
            }
            
            return cell
        }
    }
}
