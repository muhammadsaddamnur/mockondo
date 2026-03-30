import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = frame
        contentViewController = flutterViewController
        setFrame(windowFrame, display: true)

        // Prevent the native macOS gray window background from bleeding through
        // transparent Flutter layers (visible in release builds).
        self.backgroundColor = NSColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1.0)

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }
}
