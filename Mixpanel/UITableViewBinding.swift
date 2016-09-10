//
//  UITableViewBinding.swift
//  Mixpanel
//
//  Created by Yarden Eitan on 8/24/16.
//  Copyright © 2016 Mixpanel. All rights reserved.
//

import Foundation

class UITableViewBinding: CodelessBinding {


    init(eventName: String, path: String, delegate: AnyClass) {
        super.init(eventName: eventName, path: path)
        self.swizzleClass = delegate
    }

    convenience init?(object: [String: Any]) {
        guard let path = object["path"] as? String, path.characters.count >= 1 else {
            Logger.warn(message: "must supply a view path to bind by")
            return nil
        }

        guard let eventName = object["event_name"] as? String, eventName.characters.count >= 1 else {
            Logger.warn(message: "binding requires an event name")
            return nil
        }

        guard let tableDelegate = object["table_delegate"] as? String, let tableDelegateClass = NSClassFromString(tableDelegate) else {
            Logger.warn(message: "binding requires a table_delegate class")
            return nil
        }

        self.init(eventName: eventName,
                  path: path,
                  delegate: tableDelegateClass)

    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }


    override func execute() {
        if !running {
            let executeBlock = { (view: AnyObject?, command: Selector, tableView: AnyObject?, indexPath: AnyObject?) in
                //view?.perform(command)
                guard let tableView = tableView as? UITableView, let indexPath = indexPath as? IndexPath else {
                    return
                }
                if let root = UIApplication.shared.keyWindow?.rootViewController {
                    // select targets based off path
                    if self.path.isLeafSelected(leaf: tableView, root: root) {
                        var label = ""
                        if let cellText = tableView.cellForRow(at: indexPath)?.textLabel?.text {
                            label = cellText
                        }
                        self.track(event: self.eventName, properties: ["Cell Index": "\(indexPath.row)",
                                                                       "Cell Section": "\(indexPath.section)",
                                                                       "Cell Label": label])
                    }
                }
            }

            //swizzle
            //Swizzler.swizzleSelector(selector: NSSelectorFromString("tableView:didSelectRowAtIndexPath:"),
            //                         aClass: swizzleClass,
            //                         block: executeBlock,
            //                         name: name)
            let castedBlock: AnyObject = unsafeBitCast(executeBlock as @convention(executeBlock) (AnyObject, Selector, AnyObject, AnyObject) -> (), to: AnyObject.self)
            let originalSelector = NSSelectorFromString("tableView:didSelectRowAtIndexPath:")
            let impBlock = imp_implementationWithBlock(unsafeBitCast(executeBlock, to: AnyObject.self))
            let originalMethod = class_getInstanceMethod(swizzleClass, originalSelector)
            let swizzledMethod = class_getInstanceMethod(swizzleClass, swizzledSelector)
            method_setImplementation(originalMethod, impBlock)


            running = true
        }
    }

    override func stop() {
        if running {
            //unswizzle
            Swizzler.unswizzleSelector(selector: NSSelectorFromString("tableView:didSelectRowAtIndexPath:"),
                aClass: swizzleClass,
                name: name)
            running = false
        }
    }

    func parentTableView(cell: UIView) -> UITableView {
        return UITableView()
    }

    override var description: String {
        return "UITableView Codeless Binding: \(eventName) for \(path)"
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? UITableViewBinding else {
            return false
        }

        if object === self {
            return true
        } else {
            return super.isEqual(object)
        }
    }

    override var hash: Int {
        return super.hash
    }
}

extension UITableView {

    @objc func newDidSelectRowAtIndexPath(tableView: UITableView, indexPath: IndexPath) {
        self.newDidSelectRowAtIndexPath(tableView: tableView, indexPath: indexPath)

    }

}
