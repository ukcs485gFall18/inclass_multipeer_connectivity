//
//  CoreDataManager.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/25/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//  Starter code: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/InitializingtheCoreDataStack.html#//apple_ref/doc/uid/TP40001075-CH4-SW1

import Foundation
import CoreData

/**
    This is the main class for managing CoreData. It is recommend to initialize the CoreDataManager by accessing sharedCoreDataManager. Once initialized data is created, modified, and deleted by accessing managedObjectContext.
 
    - important: This file doesn't need to be changed to complete any part of this assignment.
 
*/
class CoreDataManager: NSObject {
    
    /**
        A singleton shared property of the CoreData. Once initialized, it cannot be changed. All other classes that need to use CoreData should use this one only
     
    */
    static let sharedCoreDataManager = CoreDataManager(databaseName: kCoreDataDBName, completionClosure: {})
    
    /**
        Scratchpad to modify data temporarily, data doesn't persity unless you save. This is exposed to the application publicly.
     
    */
    var managedObjectContext: NSManagedObjectContext
    
    /**
        The current state of CoreData being ready
     
    */
    fileprivate var isReady = false
    
    /**
        Read-only value that gives the current state of CoreData being ready. This can be accessed publicly
     
    */
    var isCoreDataReady:Bool{
        get{
            return isReady
        }
    }
    
    /**
        Initializes CoreData. Asynchronously returns all rooms that were found
        
        - parameters:
            - databaseName: The name of the CoreData database
            - completionClosure: Called when everything is finished
     
    */
    init(databaseName: String, completionClosure: @escaping () -> ()) {
        
        // This resource is the same name as your xcdatamodeld contained in your project.
        guard let modelURL = Bundle.main.url(forResource: kCoreDataDBModel, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        
        // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = psc
        super.init()
        
        //The rest of the setup can end up blocking the main thread, so it's dispatched on a background thread to allow the main thread to handle UI calls.
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else{
                fatalError("Unable to resolve document directory")
            }
            
            // The directory the application uses to store the Core Data store file. This code uses a file named "databaseName.sqlite" in the application's documents directory.
            let storeURL = docURL.appendingPathComponent("\(databaseName).sqlite")
            let failureReason = "There was an error creating or loading the application's saved data."
            
            do {
                //These options allow for CoreData migrations automatically
                let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                               NSInferMappingModelAutomaticallyOption: true]
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
                
                //The callback block is expected to complete the User Interface and therefore should be presented back on the main queue so that the user interface does not need to be concerned with which queue this call is coming from.
                DispatchQueue.main.sync(execute: {
                    print("CoreData initialized")
                    self.isReady = true //Set the flag just incase anyone needs to know later if CoreData is ready
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationCoreDataInitialized), object: nil) //Let anyone know who's "observing" that CoreData has been fully initialized and ready to use
                    completionClosure()
                })
                
            } catch {
                
                // Report any error we got.
                var dict = [String: Any]()
                dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
                dict[NSLocalizedFailureReasonErrorKey] = failureReason
                dict[NSUnderlyingErrorKey] = error
                let wrappedError = NSError(domain: "problem with core data migration", code: -7, userInfo: dict)
                print("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            }
        }
    }
    
    deinit {
        _ = saveContext()
    }
    
    /**
        Queries CoreData for Peer entities based on queryCompoundPredicate. Asynchronously returns all peers that were found. Note that this query is smart as it checks if CoreData is ready.
        
        - parameters:
            - queryCompoundPredicate: Logical combinations of other predicates. Predicates can be compounded using AND and OR
            - sortBy: Sorts by a specific "Attribute" type of this "Entity". Look in the MPCChatConstants.swift file for kCoreDataPeerAttribute... to get correct types. This defaults to nil, meaning data is returned as is and not sorted in any particular way
            - inDescendingOrder: If sortBy is provided, the returned results defaults to being returned in descending order. If you want the returned results in ascending order, set this to false
            - returnObjects: An array of peers found based on queryCompoundPredicate, sortBy, and inDescendingOrder. If nothing was found, 0 entities will be returned. If an error was detected, nil will be returned
     
    */
    func queryCoreDataPeers(_ queryCompoundPredicate : NSCompoundPredicate, sortBy: String?=nil, inDescendingOrder: Bool=true, completion: (_ returnObjects: [Peer]?) -> Void) {
       
        //If CoreData isn't ready, don't try to access it as it will crash the app
        if !isReady{
            print("Warning in CoreDataManager.queryCoreDataPeers(), attempting to access CoreData when it's not ready")
            completion(nil)
            return
        }
        
        let fetchRequest:NSFetchRequest<Peer>
        
        if #available(iOS 10.0, *) {
            fetchRequest = Peer.fetchRequest()
        } else {
            // Fallback on earlier versions
            fetchRequest = NSFetchRequest(entityName: kCoreDataEntityPeer)
        }
        
        fetchRequest.predicate = queryCompoundPredicate
        
        //Add sort discriptor if needed
        if let sort = sortBy{
            
            let sortDescriptor: NSSortDescriptor
            
            // Add Sort Descriptor
            if inDescendingOrder{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: false)
            }else{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: true)
            }
            
            fetchRequest.sortDescriptors = [sortDescriptor]
        }
        
        do {
            
            let fetchedEntities = try managedObjectContext.fetch(fetchRequest)
            completion(fetchedEntities)
            
        } catch {
            print(error)
            completion(nil)
        }
    }
    
    /**
        Queries CoreData for Room entities based on queryCompoundPredicate. Asynchronously returns all peers that were found. Note that this query is smart as it checks if CoreData is ready.
        
        - parameters:
            - queryCompoundPredicate: Logical combinations of other predicates. Predicates can be compounded using AND and OR
            - sortBy: Sorts by a specific "Attribute" type of this "Entity". Look in the MPCChatConstants.swift file for kCoreDataPeerAttribute... to get correct types. This defaults to nil, meaning data is returned as is and not sorted in any particular way
            - inDescendingOrder: If sortBy is provided, the returned results defaults to being returned in descending order. If you want the returned results in ascending order, set this to false
            - returnObjects: An array of peers found based on queryCompoundPredicate, sortBy, and inDescendingOrder. If nothing was found, 0 entities will be returned. If an error was detected, nil will be returned
     
    */
    func queryCoreDataRooms(_ queryCompoundPredicate : NSCompoundPredicate, sortBy: String?=nil, inDescendingOrder: Bool=true, completion: (_ returnObjects: [Room]?) -> Void) {
        
        //Don't execute if not available
        if !isReady{
            print("Warning in CoreDataManager.queryCoreDataRooms(), attempting to access CoreData when it's not ready")
            completion(nil)
            return
        }
        
        let fetchRequest:NSFetchRequest<Room>
        
        if #available(iOS 10.0, *) {
            fetchRequest = Room.fetchRequest()
        } else {
            // Fallback on earlier versions
            fetchRequest = NSFetchRequest(entityName: kCoreDataEntityRoom)
        }
        
        fetchRequest.predicate = queryCompoundPredicate
        
        //Add sort discriptor if needed
        if let sort = sortBy{
            
            let sortDescriptor: NSSortDescriptor
            
            // Add Sort Descriptor
            if inDescendingOrder{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: false)
            }else{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: true)
            }
            
            fetchRequest.sortDescriptors = [sortDescriptor]
        }
        
        do {
            
            let fetchedEntities = try managedObjectContext.fetch(fetchRequest)
            completion(fetchedEntities)
            
        } catch {
            print(error)
            completion(nil)
        }
    }
    
    /**
        Queries CoreData for Messages entities based on queryCompoundPredicate. Asynchronously returns all peers that were found. Note that this query is smart as it checks if CoreData is ready.
        
        - parameters:
            - queryCompoundPredicate: Logical combinations of other predicates. Predicates can be compounded using AND and OR
            - sortBy: Sorts by a specific "Attribute" type of this "Entity". Look in the MPCChatConstants.swift file for kCoreDataPeerAttribute... to get correct types. This defaults to nil, meaning data is returned as is and not sorted in any particular way
            - inDescendingOrder: If sortBy is provided, the returned results defaults to being returned in descending order. If you want the returned results in ascending order, set this to false
            - returnObjects: An array of peers found based on queryCompoundPredicate, sortBy, and inDescendingOrder. If nothing was found, 0 entities will be returned. If an error was detected, nil will be returned
     
    */
    func queryCoreDataMessages(_ queryCompoundPredicate : NSCompoundPredicate, sortBy: String?=nil, inDescendingOrder: Bool=true, completion: (_ returnObjects: [Message]?) -> Void) {
        
        //Don't execute if not available
        if !isReady{
            print("Warning in CoreDataManager.queryCoreDataMessages(), attempting to access CoreData when it's not ready")
            completion(nil)
            return
        }
        
        let fetchRequest:NSFetchRequest<Message>
        
        if #available(iOS 10.0, *) {
            fetchRequest = Message.fetchRequest()
        } else {
            // Fallback on earlier versions
            fetchRequest = NSFetchRequest(entityName: kCoreDataEntityMessage)
        }
        
        fetchRequest.predicate = queryCompoundPredicate
        
        //Add sort discriptor if needed
        if let sort = sortBy{
            
            let sortDescriptor: NSSortDescriptor
            
            // Add Sort Descriptor
            if inDescendingOrder{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: false)
            }else{
                sortDescriptor = NSSortDescriptor(key: sort, ascending: true)
            }
            
            fetchRequest.sortDescriptors = [sortDescriptor]
        }
        
        do {
            
            let fetchedEntities = try managedObjectContext.fetch(fetchRequest)
            completion(fetchedEntities)
            
        } catch {
            print(error)
            completion(nil)
        }
    }
    
    /**
        Persists any modified data on .managedObjectContext.
        
        - returns:
            - True if the data was persisted. False otherwise
    */
    func saveContext()->Bool {
        //Only needs to save if there has been changes made, otherwise the data is already persisted
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                print("Could not save changes to coreData, unresolved error \(error)")
                return false
            }
        }
        return true
    }
        
}
