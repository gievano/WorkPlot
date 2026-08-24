import UIKit
import UniformTypeIdentifiers
import ObjectiveC

// Force every document picker opened for importing to copy the picked file
// into the app's Inbox (asCopy: true). Mirrors Ketamine's import fix: a
// security-scoped URL returned with asCopy: false is frequently unreadable
// from the sandbox, so imports silently fail. Copying makes the file a
// regular, always-accessible Inbox item. Runs once at module load.
extension UIDocumentPickerViewController {
    @objc func workplot_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        workplot_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

private let _workplotDocumentPickerPatch: Void = {
    if let original = class_getInstanceMethod(
        UIDocumentPickerViewController.self,
        #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))
    ),
    let replacement = class_getInstanceMethod(
        UIDocumentPickerViewController.self,
        #selector(UIDocumentPickerViewController.workplot_init(forOpeningContentTypes:asCopy:))
    ) {
        method_exchangeImplementations(original, replacement)
    }
}()
