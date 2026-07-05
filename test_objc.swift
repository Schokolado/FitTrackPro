import Foundation

class Monitor {}
let obj = NSObject()
objc_setAssociatedObject(obj, "monitor", Monitor(), .OBJC_ASSOCIATION_RETAIN)
