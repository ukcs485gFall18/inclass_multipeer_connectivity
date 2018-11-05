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
    var messagesArray = [[String:String]]()
    var messagesToDisplay = [Message]()
    var model = ChatModel() //This initialization is replaced by the BrowserView segue preperation
    var room: Room?
    var isConnected = false

    @IBOutlet weak var txtChat: UITextField!
    @IBOutlet weak var tblChat: UITableView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if room == nil{
            print("Error in CharViewController, room == nil")
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        model.getAllMessagesFrom(room!, completion: {
            (messagesFound) -> Void in
            
            guard let messages = messagesFound else{
                return
            }
            
            messagesToDisplay = messages
            tblChat.reloadData()
        })
        
    }
    
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
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            tblChat.scrollToRow(at: NSIndexPath(row: messagesArray.count - 1, section: 0) as IndexPath, at: UITableView.ScrollPosition.bottom, animated: true)
        }
    }
    
}

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        guard let thisRoom = room else{
            return true
        }
        
        model.storeNewMessage(content: textField.text!, fromPeer: appDelegate.peerUUID, inRoom: thisRoom, completion: {
            (messageStored) -> Void in
            
            guard let message = messageStored else{
                return
            }
            
            let messageDictionary: [String: String] = [
                kCommunicationsMessageContentTerm: textField.text!,
                kCommunicationsMessageUUIDTerm: message.uuid
            ]
            
            messagesToDisplay.append(message)
            
            OperationQueue.main.addOperation{ () -> Void in
                self.updateTableview()
                
                let connectedPeers = self.appDelegate.mpcManager.getPeersConnectedTo()
                
                OperationQueue.main.addOperation{ () -> Void in
                    if self.appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeers: connectedPeers){
                        
                        print("Sent message \(message.content) to room \(thisRoom.name)")
                        
                    }else{
                        print("Couldn't send message \(message.content) to room \(thisRoom.name)")
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
        
        guard let thisRoom = room else{
            return
        }
        
        //Check to see if this is a peer we were connected to
        model.lostPeer(peerHash, room: thisRoom, completion: {
            (success) -> Void in
            
            if success{
                let alert = UIAlertController(title: "", message: "Connections was lost with \(peerName)", preferredStyle: UIAlertController.Style.alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                    _ = self.model.save()
                    self.dismiss(animated: true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
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
            
            guard let thisRoom = room else{
                print("Error: this Chat doesn't have a room, this should never happen")
                return
            }
            
            guard let uuid = dataDictionary[kCommunicationsMessageUUIDTerm] else{
                print("Error: received messaged is lacking UUID")
                return
            }
            
            guard let fromPeerUUID = model.getPeerUUIDFromHash(fromPeerHash) else{
                return
            }
            
            model.storeNewMessage(uuid, content: message, fromPeer: fromPeerUUID, inRoom: thisRoom, completion: {
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
        
        if message.owner.peerUUID == appDelegate.peerUUID{
            senderLabelText = "I said"
            senderColor = UIColor.purple
        }else{
            senderLabelText = message.owner.peerName + " said"
            senderColor = UIColor.orange
        }
        
        cell.nameLabel?.text = senderLabelText
        cell.nameLabel?.textColor = senderColor
        cell.messageLabel?.text = message.content
        
        return cell
    }
}
