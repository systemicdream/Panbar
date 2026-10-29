import AppKit

let app = NSApplication.shared
let controller = PanbarController()
app.setActivationPolicy(.accessory)
controller.start()
app.run()
