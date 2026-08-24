//
//  UIApplication+Wallpaper.swift
//  WorkPlot
//
//  Minimal UIKit alert/progress helpers adapted from Pocket Poster's
//  UIApplication extensions, so the ported PosterBoard managers can call
//  UIApplication.shared.alert / confirmAlert / dismissAlert / change.
//
//  Source: github.com/leminlimez/Pocket-Poster (GPL-3.0). See THIRD_PARTY_NOTICES.md.
//

import UIKit

extension UIApplication {
    private static var currentAlert: UIAlertController?

    private static func topViewController(
        _ controller: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController
    ) -> UIViewController? {
        if let nav = controller as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topViewController(tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(presented)
        }
        return controller
    }

    func alert(title: String? = nil, body: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            Self.topViewController()?.present(alert, animated: true)
        }
    }

    func alert(title: String?, body: String, onOK: @escaping () -> Void) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onOK() })
            Self.topViewController()?.present(alert, animated: true)
        }
    }

    func confirmAlert(
        title: String?,
        body: String,
        onOK: @escaping () -> Void,
        noCancel: Bool = false
    ) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onOK() })
            if !noCancel {
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            }
            Self.topViewController()?.present(alert, animated: true)
        }
    }

    func dismissAlert(animated: Bool = true) {
        DispatchQueue.main.async {
            Self.currentAlert?.dismiss(animated: animated)
            Self.currentAlert = nil
        }
    }

    /// Shows or updates a transient progress alert.
    /// Mirrors Pocket Poster's `change(title:body:)` used during long ops.
    func change(title: String, body: String) {
        DispatchQueue.main.async {
            if let existing = Self.currentAlert {
                existing.title = title
                existing.message = body
                return
            }
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            Self.currentAlert = alert
            Self.topViewController()?.present(alert, animated: true)
        }
    }
}

struct Haptic {
    static let shared = Haptic()
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
