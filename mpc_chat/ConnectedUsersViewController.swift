//
//  ConnectedUsersViewController.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/16/19.
//  Copyright © 2019 University of Kentucky - CS 485G. All rights reserved.
//

import UIKit

class ConnectedUsersViewController: UIViewController {
    
    var connectedUsers = [String]()
    
    @IBOutlet weak var connectedUsersTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        connectedUsersTableView.delegate = self
        connectedUsersTableView.dataSource = self
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ConnectedUsersViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connectedUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "idCellConnected")!
        
        //cell.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        //cell.alpha=0.5
        
        cell.textLabel?.text = connectedUsers[indexPath.row]
        
        return cell
    }
    
    
}
