//
//  FetchedResultsTableViewController.swift
//  FetchedResultsTableViewController
//
//  Created by David M Reed on 11/25/14.
//  Copyright (c) 2014 David M Reed. All rights reserved.
//

import UIKit
import CoreData

public typealias ConfigureCellClosure = (cell: UITableViewCell, indexPath: NSIndexPath, object: AnyObject) -> Void
public typealias ReorderCellClosure = (items: NSArray) -> Void
public typealias WillDeleteObjectClosure = (object: NSManagedObject) -> Void

public class FetchedResultsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    // closure for displaying a NSManagedObjct in a cell at a given indexPath
    public var configureCellClosure: ConfigureCellClosure? = nil

    // closure that indicates how to update the model when a cell is moved
    public var reorderCellClosure: ReorderCellClosure? = nil

    // closure that is called before an NSManagedObject is deleted by the tableview editing
    public var willDeleteObjectClosure : WillDeleteObjectClosure? = nil

    // indicates whether or not the the table view is editable for inserting/deleting
    public var allowEditing = false

    // indicates whether or not user can re-order cells when editing
    public var allowReordering = false

    // the UITableViewCell re-use identifier from Interface Builder
    // make optional nil so we get a crash if forget to set
    public var cellReuseIdentifier: String? = nil

    // flag for use when re-ordering cells and model changes
    private var userDrivenDataModelChange = false

    // our NSFetchedResultsController
    // call makeFetechedResultsController to actually set it
    public var fetchedResultsController: NSFetchedResultsController? = nil {
        didSet {
            if oldValue != fetchedResultsController {
                if let frc = fetchedResultsController {
                    if self.title == nil && (self.navigationController == nil || self.navigationItem.title == nil) {
                        self.title = self.fetchedResultsController!.fetchRequest.entity!.name
                    }
                    frc.delegate = self
                    self.performFetch()
                }
                else {
                    self.tableView.reloadData()
                }
            }
        }
    }

    public func makeFetchedResultsControllerForEntityNamed(entityName: String, inManagedObjectContext moc: NSManagedObjectContext, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil, sectionNameKeyPath: String? = nil, cacheName: String? = nil, fetchBatchSize: Int = 20) {

        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: moc)
        fetchRequest.entity = entity
        fetchRequest.fetchBatchSize = fetchBatchSize
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate



        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: moc, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
    }

    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // helper method to call performFetch on our
    func performFetch() {
        if let frc = fetchedResultsController {
            var error: NSError? = nil
            frc.performFetch(&error)
            if error != nil {
                println("error performing fetch \(error?.localizedDescription)\n\(error?.localizedFailureReason)")
            }
        }
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.fetchedResultsController?.sections?.count ?? 0
    }

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController?.sections![section] as NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }

    public func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let object = self.fetchedResultsController?.objectAtIndexPath(indexPath) as NSManagedObject
        self.configureCellClosure?(cell: cell, indexPath: indexPath, object: object)
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // if you get a crash here about unwrapping optional, you forget to set the cellReuseIdentifier in your subclass of CoreDataTableViewController
        let cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier!, forIndexPath: indexPath) as UITableViewCell

        // Configure the cell...
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }

    // Override to support conditional editing of the table view.
    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return allowEditing
    }


    // Override to support editing the table view.
    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            if let context = self.fetchedResultsController?.managedObjectContext {
                let object = self.fetchedResultsController?.objectAtIndexPath(indexPath) as NSManagedObject
                willDeleteObjectClosure?(object: object)
                context.deleteObject(object)
            }
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }


    // Override to support rearranging the table view.
    public override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

        // prevent NSFetchedResultsController from responding to the changes we make
        userDrivenDataModelChange = true

        if fetchedResultsController != nil {
            var items = self.fetchedResultsController!.fetchedObjects as [NSManagedObject]
            // convert to NSMutableArray so we can re-order
            // toll free bridging from Swift array to NSArray (if items are NSObject subclasses which they are)
            var itemsArray = (items as NSArray).mutableCopy() as NSMutableArray
            // get the item
            let item = self.fetchedResultsController!.objectAtIndexPath(fromIndexPath) as NSManagedObject
            // remove it from its old spot
            itemsArray.removeObject(item)
            // and insert it at its new spot
            itemsArray.insertObject(item, atIndex: toIndexPath.row)

            // call the closure method that can update the model to indicate the new order
            self.reorderCellClosure?(items: itemsArray)
        }

        // allow NSFetchedResultsController to respond to changes
        userDrivenDataModelChange = false
    }

    // Override to support conditional rearranging of the table view.
    public override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return allowReordering
    }

    // only allow moving within same section
    // the sections are created by the the NSFechedResultsController if you specify a sectionNameKeyPath so if you move all
    // the rows from a section, the internal consistency of number of sections and displayed sections gets out of sync
    public override func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {

        if sourceIndexPath.section == proposedDestinationIndexPath.section {
            return proposedDestinationIndexPath
        }
        else {
            return sourceIndexPath
        }
    }

    // MARK: - NSFetchedResultsController delegate

    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        // do nothing if user is reordering the cells
        if userDrivenDataModelChange {
            return
        }
        self.tableView.beginUpdates()
    }

    public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        if userDrivenDataModelChange {
            return
        }
        switch type {
        case .Insert:
            self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:
            return
        }
    }

    public func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        if userDrivenDataModelChange {
            return
        }
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
        case .Update:
            self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        default:
            return
        }
    }

    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if userDrivenDataModelChange {
            return
        }
        self.tableView.endUpdates()
        // if uncomment reloadData() then animations for deleting do not happen
        //self.tableView.reloadData()
    }

    /*
    // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
    // In the simplest, most efficient, case, reload the table view.
    self.tableView.reloadData()
    }
    */

}


    /*
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as UITableViewCell

        // Configure the cell...

        return cell
    }
    */

