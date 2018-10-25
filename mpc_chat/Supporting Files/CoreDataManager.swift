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

class CoreDataManager: NSObject {
    
    var managedObjectContext: NSManagedObjectContext
    
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
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else{
                fatalError("Unable to resolve document directory")
            }
            
            /* The directory the application uses to store the Core Data store file.
             This code uses a file named "databaseName.sqlite" in the application's documents directory.
             */
            let storeURL = docURL.appendingPathComponent("\(databaseName).sqlite")
            let failureReason = "There was an error creating or loading the application's saved data."
            
            do {
                //These options allow for CoreData migrations automatically
                let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                               NSInferMappingModelAutomaticallyOption: true]
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
                //The callback block is expected to complete the User Interface and therefore should be presented back on the main queue so that the user interface does not need to be concerned with which queue this call is coming from.
                DispatchQueue.main.sync(execute: completionClosure)
                
            } catch {
                
                // Report any error we got.
                var dict = [String: AnyObject]()
                dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
                dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
                dict[NSUnderlyingErrorKey] = error as NSError
                let wrappedError = NSError(domain: "problem with core data migration", code: -7, userInfo: dict)
                // Replace this with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            }
        }
        
        super.init()
    }
    
    deinit {
        saveContext()
    }
    
    func queryCoreDataMessages(_ queryCompoundPredicate : NSCompoundPredicate, sortBy: String?=nil, inDescendingOrder: Bool=true, completion: (_ returnObjects: [Peers]?) -> Void) {
        
        let fetchRequest:NSFetchRequest<Peers>
        
        if #available(iOS 10.0, *) {
            fetchRequest = Peers.fetchRequest()
        } else {
            // Fallback on earlier versions
            fetchRequest = NSFetchRequest(entityName: kCoreDataEntityPeers)
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
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \(error)")
            }
        }
    }
        
}
