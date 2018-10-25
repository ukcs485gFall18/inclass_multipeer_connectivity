//
//  ViewController.swift
//  
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//  Followed and made additions to original tutorial by Gabriel Theodoropoulos
//  Swift: http://www.appcoda.com/chat-app-swift-tutorial/
//  Objective C: http://www.appcoda.com/intro-multipeer-connectivity-framework-ios-programming/
//

import UIKit
import CoreData

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MPCManagerDelegate {
    
    let appDelagate = UIApplication.shared.delegate as! AppDelegate
    var isCoreDataAvailable = false
    
    @IBOutlet weak var tblPeers: UITableView!
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.handleCoreDataInitializedReceived(_:)), name: Notification.Name(rawValue: kNotificationMPCCoreDataInitialized), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view
        
        tblPeers.delegate = self
        tblPeers.dataSource = self
        
        appDelagate.mpcManager.delegate = self
        
        // Register cell classes
        tblPeers.register(UITableViewCell.self, forCellReuseIdentifier: "idCellPeer")
        /*
        let test = ["Apple":"Computer"]
        
        guard let myCompute = test["Apples"] else{
            return
        }
        
        print("Why do I never get here")*/
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleCoreDataInitializedReceived(_ notification: NSNotification) {
        //let receivedDataDictionary = notification.object as! [String: Any]
        isCoreDataAvailable = true
        
        tblPeers.reloadData() //Reload cells to reflect coreData
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
    
    
    
    // MARK: UITableView related method implementation
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return appDelagate.mpcManager.foundPeerHashValues.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "idCellPeer") as? BrowserTableViewCell else{
            return UITableViewCell(style: .default, reuseIdentifier: "idCellPeer")
        }
        
        let peerHashValue = appDelagate.mpcManager.foundPeerHashValues[indexPath.row]
        
        guard let displayName = appDelagate.mpcManager.getPeerDisplayName(peerHashValue) else{
            return cell
        }
        
        cell.peerNameLabel.text = displayName
        
        if isCoreDataAvailable{
            //appDelagate.coreDataManager.queryCoreDataMessages(<#T##queryCompoundPredicate: NSCompoundPredicate##NSCompoundPredicate#>, completion: <#T##([Peers]?) -> Void#>)
            /*
            let predicate:NSPredicate
            
            if uuids == nil{
                predicate = NSPredicate(format: "\(kAOCDUserAttrUUID) IN %@", [(PFUser.current()! as! Users).uuid])
            }else{
                predicate = NSPredicate(format: "\(kAOCDUserAttrUUID) IN %@", uuids!)
            }
            
            let compoundQuery = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate])
            */
        }else{
            cell.isPeerLabel.text = "Uknown"
        }
        
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let peerHashValue = appDelagate.mpcManager.foundPeerHashValues[indexPath.row]
        
        //TODO: This function is used to send peer info we are interested in
        appDelagate.mpcManager.invitePeer(peerHashValue)
        
    }
    
    // MARK: MPCManager delegate method implementation
    func foundPeer() {
        tblPeers.reloadData()
    }
    
    func lostPeer() {
        tblPeers.reloadData()
    }
    
   
    func invitationWasReceived(_ fromPeer: String, completion: @escaping (_ fromPeer: String, _ accept: Bool) ->Void) {
        
        
        let alert = UIAlertController(title: "", message: "\(fromPeer) wants to chat with you.", preferredStyle: UIAlertController.Style.alert)
        
        let acceptAction: UIAlertAction = UIAlertAction(title: "Accept", style: UIAlertAction.Style.default)  {(alertAction) -> Void in
            completion(fromPeer, true)
        }
        
        let declineAction: UIAlertAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel) {(alertAction) -> Void in
            completion(fromPeer, false)
        }
        
        alert.addAction(acceptAction)
        alert.addAction(declineAction)
        
        OperationQueue.main.addOperation{ () -> Void in
            self.present(alert, animated: true, completion: nil)
        }

    }
    
    func connectedWithPeer(_ peerHash: Int) {
        
        //Save data to CoreData
        //Check if the current message is already stored.
        /*
        let predicate = NSPredicate(format: "\(peerHash) == %@", Peers)
        
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>
        
        if #available(iOS 10.0, *) {
            
            fetchRequest = Peers.fetchRequest()
            
        } else {
            // Fallback on earlier versions
            fetchRequest = NSFetchRequest(entityName: kCoreDataEntityPeers)
        }
        
        fetchRequest.predicate = predicate
        
        do {
            
            let fetchedEntities = try self.coreDataManager.managedObjectContext.fetch(fetchRequest) as! [Peers]
            
            //If object already in the database need to see if the Clound version is newer
            if fetchedEntities.count > 0{
                
            }else{
                //Must be a new item that needs to be store to the local database
                let newMessage = NSEntityDescription.insertNewObject(forEntityName: kCoreDataEntityPeers, into: self.coreDataManager.managedObjectContext) as! Peers
            
                
                do {
                    try self.coreDataManager.managedObjectContext.save()
                    
                    //completion(true, nil)
                    return
                    
                } catch {
                    //completion(false, NSError(domain: "Error in SOSMiddleware.storeMessageItemFromAlleyOopMessage. Could not save to database", code: -7, userInfo: nil))
                    return
                }
            }
        }catch {
            //completion(false, NSError(domain: "Error in SOSMiddleware.storeMessageItemFromAlleyOopMessage. Could not search database for uuid", code: -7, userInfo: nil))
            return
        }
        */
        OperationQueue.main.addOperation{ () -> Void in
            self.performSegue(withIdentifier: "idSegueChat", sender: self)
        }
        
    }
    
}


