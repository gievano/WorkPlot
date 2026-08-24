import UIKit
import UniformTypeIdentifiers
import ObjectiveC

// Force every document picker opened for importing to copy the picked file
// into the app's Inbox (asCopy: true). A security-scoped URL returned with
// asCopy: false is frequently unreadable from the sandbox, so imports
// silently fail. Copying yields a plain, always-accessible file.
// Mirrors Ketamine's proven import fix. Triggered once from WorkPlotApp.init().
extension UIDocumentPickerViewController {
    @objc func workplot_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        workplot_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }

    static let workplotSwizzleOnce: Void = {
        let original = class_getInstanceMethod(
            UIDocumentPickerViewController.self,
            #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))
        )!
        let replacement = class_getInstanceMethod(
            UIDocumentPickerViewController.self,
            #selector(UIDocumentPickerViewController.workplot_init(forOpeningContentTypes:asCopy:))
        )!
        method_exchangeImplementations(original, replacement)
    }()
}
