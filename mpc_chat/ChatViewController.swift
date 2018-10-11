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

class ChatViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var messagesArray: [[String:String]] = []
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var txtChat: UITextField!
    @IBOutlet weak var tblChat: UITableView!

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tblChat.delegate = self
        tblChat.dataSource = self
        
        tblChat.estimatedRowHeight = 60.0
        tblChat.rowHeight = UITableView.automaticDimension

        txtChat.delegate = self
        
        tblChat.estimatedRowHeight = 60.0
        tblChat.rowHeight = UITableView.automaticDimension
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleMPCChatReceivedDataWithNotification(_:)), name: Notification.Name(rawValue: kNotificationMPCDataReceived), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleMPCChatReceivedDisconnectionWithNotification(_:)), name: Notification.Name(rawValue: kNotificationMPCDisconnetion), object: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: IBAction method implementation
    
    @IBAction func endChat(_ sender: AnyObject) {
    
        let messageDictionary: [String: String] = [kCommunicationsMessageTerm: kCommunicationsEndConnectionTerm]
        let connectedPeers = appDelegate.mpcManager.getPeersConnectedTo()
        
        if appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeer: connectedPeers ){
            self.dismiss(animated: true, completion: { () -> Void in
                print("Disconneced from session")
            })
        }
        
    }
    
    
    // MARK: UITableView related method implementation
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesArray.count;
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "idCell") as! ChatTableViewCell

        let currentMessage = messagesArray[indexPath.row] as Dictionary<String, String>
        
        if let sender = currentMessage[kCommunicationsSenderTerm] {
            var senderLabelText: String
            var senderColor: UIColor
            
            if sender == kCommunicationsSelfTerm{
                senderLabelText = "I said:"
                senderColor = UIColor.purple
            }else{
                senderLabelText = sender + " said:"
                senderColor = UIColor.orange
            }
            
            cell.nameLabel?.text = senderLabelText
            cell.nameLabel?.textColor = senderColor
        }
        
        if let message = currentMessage[kCommunicationsMessageTerm]{
            cell.messageLabel?.text = message
        }
        
        return cell
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let messageDictionary: [String: String] = [kCommunicationsMessageTerm: textField.text!]
        let connectedPeers = appDelegate.mpcManager.getPeersConnectedTo()
        
        if appDelegate.mpcManager.sendData(dictionaryWithData: messageDictionary, toPeer: connectedPeers ){
            let dictionary: [String: String] = [kCommunicationsSenderTerm: kCommunicationsSelfTerm, kCommunicationsMessageTerm: textField.text!]
            messagesArray.append(dictionary)
            
            self.updateTableview()
        }else{
            print("Could not send data")
        }
        
        textField.text = ""
        return true
    }
    
    func updateTableview(){
        self.tblChat.reloadData()
        
        if self.tblChat.contentSize.height > self.tblChat.frame.size.height {
            tblChat.scrollToRow(at: NSIndexPath(row: messagesArray.count - 1, section: 0) as IndexPath, at: UITableView.ScrollPosition.bottom, animated: true)
        }
    }
    
    @objc func handleMPCChatReceivedDataWithNotification(_ notification: NSNotification) {
        let receivedDataDictionary = notification.object as! Dictionary<String, AnyObject>
        
        //Extract the data and the source peer from the received dictionary
        let data = receivedDataDictionary[kCommunicationsDataTerm] as? Data
        let fromPeer = receivedDataDictionary[kCommunicationsFromPeerTerm] as! String
        
        //Convert the data (NSData) into a Dictionary object
        let dataDictionary = NSKeyedUnarchiver.unarchiveObject(with: data!) as! [String:String]
        
        //Check if there's an entry with the kCommunicationsMessageTerm key
        if let message = dataDictionary[kCommunicationsMessageTerm]{
            
            if message != kCommunicationsEndConnectionTerm  {
                //Create a new dictioary and ser the sender and the received message to it
                let messageDictionary: [String: String] = [kCommunicationsSenderTerm: fromPeer, kCommunicationsMessageTerm: message]
                
                messagesArray.append(messageDictionary)
                
                //Reload the tableview data and scroll to the bottom using the main thread
                OperationQueue.main.addOperation({ () -> Void in
                    self.updateTableview()
                })
            }else{
                let alert = UIAlertController(title: "", message: "\(fromPeer) ended this chat.", preferredStyle: UIAlertController.Style.alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                    self.appDelegate.mpcManager.disconnect()
                    self.dismiss(animated: true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
            
                })
            }
        }
    }
    
    @objc func handleMPCChatReceivedDisconnectionWithNotification(_ notification: NSNotification) {
        let receivedDataDictionary = notification.object as! [String: Any]
        
        //Extract the data and the source peer from the received dictionary
        let data = receivedDataDictionary[kCommunicationsDataTerm ] as? Data
        let fromPeer = receivedDataDictionary[kCommunicationsFromPeerTerm] as! String
        
        //Convert the data (NSData) into a Dictionary object
        let dataDictionary = NSKeyedUnarchiver.unarchiveObject(with: data!) as! [String:String]
        
        //Check if there's an entry with the kCommunicationsMessageTerm key
        if let message = dataDictionary[kCommunicationsMessageTerm]{
            
            if message != kCommunicationsLostConnectionTerm  {
                //Create a new dictioary and ser the sender and the received message to it
                let messageDictionary: [String: String] = [kCommunicationsSenderTerm: fromPeer, kCommunicationsMessageTerm: message]
                
                messagesArray.append(messageDictionary)
                
                //Reload the tableview data and scroll to the bottom using the main thread
                OperationQueue.main.addOperation({ () -> Void in
                    self.updateTableview()
                })
            }else{
                let alert = UIAlertController(title: "", message: "Connections was lost with \(fromPeer)", preferredStyle: UIAlertController.Style.alert)
                
                let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: UIAlertAction.Style.default) { (alertAction) -> Void in
                    self.appDelegate.mpcManager.disconnect()
                    self.dismiss(animated: true, completion: nil)
                }
                
                alert.addAction(doneAction)
                
                OperationQueue.main.addOperation({ () -> Void in
                    self.present(alert, animated: true, completion: nil)
                })
            }
        }
    }
    
    
}
