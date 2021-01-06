import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    self.contentViewController = flutterViewController
    self.setFrame(NSRect(origin: self.frame.origin, size: NSSize(width: 1000, height: 650)), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    super.awakeFromNib()
    
    // Remove the title bar and expand content to fill the entire window.
    self.setContentSize(NSSize(width: 1000, height: 650))
    self.styleMask.update(with: StyleMask.fullSizeContentView)
    self.titleVisibility = TitleVisibility.hidden
    self.titlebarAppearsTransparent = true
    self.backgroundColor = NSColor.white
  }
}
