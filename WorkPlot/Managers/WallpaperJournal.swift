//
//  WallpaperJournal.swift
//  WorkPlot
//
//  Persistent record of the descriptor folder names WorkPlot wrote into
//  PosterBoard, so installs can be undone later even across launches.
//

import Foundation

final class WallpaperJournal {
    static let shared = WallpaperJournal()

    private static let storageKey = "WorkPlotAddedWallpaperDescriptors"

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Descriptor folder names written by WorkPlot, in insertion order, unique.
    var addedDescriptors: [String] {
        defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    func record(_ names: [String]) {
        var current = addedDescriptors
        for name in names where !current.contains(name) {
            current.append(name)
        }
        defaults.set(current, forKey: Self.storageKey)
    }

    func remove(_ names: [String]) {
        let dropped = Set(names)
        defaults.set(addedDescriptors.filter { !dropped.contains($0) }, forKey: Self.storageKey)
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
