//
//  MasterViewController.swift
//  FetchedResultsDemo
//
//  Created by David M Reed on 11/25/14.
//  Copyright (c) 2014 David M Reed. All rights reserved.
//

import UIKit
import CoreData
import FetchedResultsTableViewController

class MasterViewController: FetchedResultsTableViewController, NSFetchedResultsControllerDelegate {

    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    var numberOfItems = 0


    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem()

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
        self.navigationItem.rightBarButtonItem = addButton
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = controllers[controllers.count-1].topViewController as? DetailViewController
        }

        // setup CoreDataTableViewController
        let sortDescriptors = [NSSortDescriptor(key: "position", ascending: true), NSSortDescriptor(key: "timeStamp", ascending: true)]
        makeFetchedResultsControllerForEntityNamed("Event", inManagedObjectContext: self.managedObjectContext!, predicate: nil, sortDescriptors: sortDescriptors, sectionNameKeyPath: nil, cacheName: "Master")


        numberOfItems = (fetchedResultsController?.fetchedObjects?.count)!
        allowEditing = true
        allowReordering = true
        cellReuseIdentifier = "Cell"

        // closure for displaying a cell
        configureCellClosure = { (cell, indexPath, object) in
            let position = object.valueForKey("position") as! Int
            cell.textLabel!.text = object.valueForKey("timeStamp")!.description + " - \(position)"
        }

        // closure for re-ordering cells
        reorderCellClosure = { items in
            // set the position based on array order
            var pos = 0
            for item in items {
                item.setValue(pos, forKey: "position")
                /*
                let ts = item.valueForKey("timeStamp")?.description
                let p = item.valueForKey("position")?.description
                println("\(ts!) \(p!)")
                */
                pos++
            }

            // and do a save
            if let context = self.fetchedResultsController?.managedObjectContext {
                var error: NSError? = nil
                if !context.save(&error) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    println("Unresolved error \(error), \(error?.userInfo)")

                }
            }
            // so we see the updated position value
            // reloadData() would not be necessary if closure did only update attributes that are not displayed
            self.tableView.reloadData()
        }

        // closure for deleting objects
        willDeleteObjectClosure = { obj in
            // update how many items we have
            self.numberOfItems = self.numberOfItems - 1
            //println(self.numberOfItems)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func insertNewObject(sender: AnyObject) {
        if let context = self.fetchedResultsController?.managedObjectContext {
            if let entity = self.fetchedResultsController?.fetchRequest.entity {
                let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! NSManagedObject

                // If appropriate, configure the new managed object.
                // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
                newManagedObject.setValue(NSDate(), forKey: "timeStamp")
                newManagedObject.setValue(numberOfItems, forKey: "position")
                numberOfItems++

                // Save the context.
                var error: NSError? = nil
                if !context.save(&error) {
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    println("Unresolved error \(error), \(error?.userInfo)")

                }
            }
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                let object = self.fetchedResultsController?.objectAtIndexPath(indexPath) as! NSManagedObject
                let controller = (segue.destinationViewController as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }
    
    
}



