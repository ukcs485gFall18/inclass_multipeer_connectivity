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

    @IBOutlet weak var roomNameTextField: UITextField!
    @IBOutlet weak var txtChat: UITextField!
    @IBOutlet weak var tblChat: UITableView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        model.getAllMessagesInRoom(completion: {
            (messagesFound) -> Void in
            
            guard let messages = messagesFound else{
                return
            }
            
            messagesToDisplay = messages
            tblChat.reloadData()
        })
        
        roomNameTextField.text = model.getRoomName()
        
        //ToDo: Need to restrict room name changes to the owner ONLY. If a user is not the owner, they shouldn't be able to edit the room name
        roomNameTextField.isEnabled = true
    }
    
    //ToDo: Need to add a button the storyboard that when tapped, opens a subView or openning to BrowserViewController. Here the user keep see more peers around and add them to the chat. Note: Only owners should be able to add people to the Chat. If someone is not the owner, they can Browse, but tapping and adding a new user to the chat should be disabled
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        appDelegate.mpcManager.messageDelegate = self
        tblChat.delegate = self
        tblChat.dataSource = self
        
        tblChat.estimatedRowHeight = 60.0
        tblChat.rowHeight = UITableView.automaticDimension

        txtChat.delegate = self
        
        tblChat.estimatedRowHeight = 60.0
        tblChat.rowHeight = UITableView.automaticDimension
        
        self.hideKeyboardWhenTappedAround()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func userChangedRoomName(_ sender: Any) {
        
        //User changed room name
        if roomNameTextField.text! != model.getRoomName(){
            model.changeRoomName(roomNameTextField.text!)
            
            //ToDo: Need to send user a message (shouldn't show on their screen) with the new roomName. Remember, only the owner of a room should be able to change the name of the room. If a Peer is not the owner, the change label should be disabled
        }
    }
    
    // MARK: IBAction method implementation
    @IBAction func endChat(_ sender: AnyObject) {
    
        let messageDictionary: [String: String] = [kCommunicationsMessageContentTerm: kCommunicationsEndConnectionTerm]
        let connectedPeers = appDelegate.mpcManager.getPeersConnectedTo()
        
        if appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeers: connectedPeers){
            
            //Give some time for connectedPeer to receive disconnect info
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                self.appDelegate.mpcManager.disconnect()
            })
            
            self.dismiss(animated: true, completion: { () -> Void in
                print("Disconneced from session")
            })
            
        }else{
            print("Couldn't send diconnect, try again")
        }
        
    }
    
    func updateTableview(){
        self.tblChat.reloadData()
        
        if self.tblChat.contentSize.height > self.tblChat.frame.size.height {
            tblChat.scrollToRow(at: NSIndexPath(row: messagesToDisplay.count - 1, section: 0) as IndexPath, at: UITableView.ScrollPosition.bottom, animated: true)
        }
    }
    
}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        model.storeNewMessage(content: textField.text!, fromPeer: appDelegate.peerUUID, completion: {
            (messageStored) -> Void in
            
            guard let message = messageStored else{
                return
            }
            
            //ToDo: This is how you send a meesage. This is a hint for sending the newRoom name to the user. What if you send a similar message with kBrowserPeerRoomName in the key and the value of the newRoomName?
            let messageDictionary: [String: String] = [
                kCommunicationsMessageContentTerm: textField.text!,
                kCommunicationsMessageUUIDTerm: message.uuid
            ]
            
            messagesToDisplay.append(message)
            
            OperationQueue.main.addOperation{ () -> Void in
                self.updateTableview()
                
                let connectedPeers = self.appDelegate.mpcManager.getPeersConnectedTo()
                
                OperationQueue.main.addOperation{ () -> Void in
                    
                    let roomName = self.model.getRoomName()
                    
                    if self.appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeers: connectedPeers){
                        print("Sent message \(message.content) to room \(roomName)")
                    }else{
                        print("Couldn't send message \(message.content) to room \(roomName)")
                    }
                }
            }
        })
        
        //Update text field with nothing
        textField.text = ""
        return true
        
    }
}

extension ChatViewController: MPCManagerMessageDelegate {
    
    func lostPeer(_ peerHash: Int, peerName: String) {
        
        //Check to see if this is a peer we were connected to
        model.lostPeer(peerHash, completion: {
            (success) -> Void in
            
            if success{
                let alert = UIAlertController(title: "", message: "Connections was lost with \(peerName)", preferredStyle: UIAlertController.Style.alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                    self.dismiss(animated: true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
                //ToDo: Need to update the lastTimeConnected when an item is already saved to CoreData. This is when you disconnected from the user. Hint: use peerHash to find peer.
                
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
                })
            }
            
        })
        
    }
    
    func messageReceived(_ fromPeerHash:Int, data: Data) {
        
        guard let fromPeer = appDelegate.mpcManager.getPeerDisplayName(fromPeerHash) else{
            return
        }
        
        //Convert the data (Data) into a Dictionary object
        let dataDictionary = NSKeyedUnarchiver.unarchiveObject(with: data) as! [String:String]
        
        //Check if there's an entry with the kCommunicationsMessageContentTerm key
        guard let message = dataDictionary[kCommunicationsMessageContentTerm] else{
            return
        }
        
        if message != kCommunicationsEndConnectionTerm  {
            
            //ToDo: Hint, this is checking for kCommunicationsMessageUUIDTerm, what if we checked for kBrowserPeerRoomName to detect a room name?
            guard let uuid = dataDictionary[kCommunicationsMessageUUIDTerm] else{
                print("Error: received messaged is lacking UUID")
                return
            }
            
            guard let fromPeerUUID = model.getPeerUUIDFromHash(fromPeerHash) else{
                return
            }
            
            model.storeNewMessage(uuid, content: message, fromPeer: fromPeerUUID, completion: {
                (messageReceived) -> Void in
                
                guard let message = messageReceived else{
                    return
                }
                
                messagesToDisplay.append(message)
                
                //Reload the tableview data and scroll to the bottom using the main thread
                OperationQueue.main.addOperation({ () -> Void in
                    self.updateTableview()
                })
            })
            
        }else{
            //fromPeer want's to disconnect
            let alert = UIAlertController(title: "", message: "\(fromPeer) ended this chat.", preferredStyle: UIAlertController.Style.alert)
            
            let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            }
            
            alert.addAction(doneAction)
            
            OperationQueue.main.addOperation({ () -> Void in
                self.present(alert, animated: true, completion: nil)
            })
        }
    }
    
}

// MARK: UITableView related method implementation
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return messagesToDisplay.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "idCell") as! ChatTableViewCell
        
        let message = messagesToDisplay[indexPath.row]
        
        var senderLabelText: String
        var senderColor: UIColor
        
        if message.owner.uuid == appDelegate.peerUUID{
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
        
        return cell
    }
}
