import AppKit

let application = NSApplication.shared
let delegate = ControlDelegate()

application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
