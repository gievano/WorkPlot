//
//  WallpaperVideoHandler.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's VideoHandler.swift (GPL-3.0).
//  Turns an imported video into a PosterBoard CAML descriptor by extracting
//  every frame as a JPG and writing the CoreAnimation document.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation
import AVFoundation
import UIKit
import CoreTransferable

extension CGImage {
    var jpg: Data? {
        UIImage(cgImage: self).jpegData(compressionQuality: 0.7)
    }
}

struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let videoFolder = WallpaperSymlink.getDocumentsDirectory()
                .appendingPathComponent("Videos", conformingTo: .directory)
            try? FileManager.default.createDirectory(at: videoFolder, withIntermediateDirectories: true)
            let copy = videoFolder.appendingPathComponent("\(UUID()).mp4")
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

enum LoadState {
    case unknown, loading, loaded(Movie), failed
}

struct LoadInfo: Identifiable, Equatable {
    static func == (lhs: LoadInfo, rhs: LoadInfo) -> Bool { lhs.id == rhs.id }

    var id = UUID()
    var autoReverses: Bool = false
    var loadState: LoadState
}

final class WallpaperVideoHandler {
    static let MaxDurationSecs = 12.0

    static func isVideoTooLong(at url: URL) -> Bool {
        let asset = AVAsset(url: url)
        return CMTimeGetSeconds(asset.duration) > MaxDurationSecs
    }

    static func createCaml(from url: URL, autoReverses: Bool) throws -> URL {
        let descrURL = WallpaperSymlink.getDocumentsDirectory()
            .appendingPathComponent(UUID().uuidString, conformingTo: .directory)
        try FileManager.default.createDirectory(at: descrURL, withIntermediateDirectories: false)

        // Copy the VideoCAML template bundle shipped with WorkPlot.
        guard let rc = Bundle.main.url(forResource: "WallpaperCAML", withExtension: nil) else {
            throw URLError(.fileDoesNotExist)
        }
        try FileManager.default.copyItem(at: rc, to: descrURL.appendingPathComponent("videoCAML"))

        let coreAnimDir = descrURL.appendingPathComponent(
            "videoCAML/versions/1/contents/9183.Custom-810w-1080h@2x~ipad.wallpaper/9183.Custom_Background-810w-1080h@2x~ipad.ca"
        )
        let assetsFolder = coreAnimDir.appendingPathComponent("assets", conformingTo: .directory)
        try FileManager.default.createDirectory(at: assetsFolder, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw AVError(.decodeFailed)
        }
        let preferredTransform = track.preferredTransform
        let size = track.naturalSize.applying(preferredTransform)
        let width = Int(abs(size.width))
        let height = Int(abs(size.height))
        let fps = track.nominalFrameRate
        let duration = CMTimeGetSeconds(asset.duration)
        let totalFrames = Int(fps * Float(duration))
        let animDur = Double(totalFrames) / Double(fps)

        var camlData = """
<?xml version="1.0" encoding="UTF-8"?>

<caml xmlns="http://www.apple.com/CoreAnimation/1.0">
<CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" hidden="0" name="_FLOATING" position="\(Int(width/2)) \(Int(height/2))">
<sublayers>
<CATransformLayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" allowsHitTesting="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" name="Chip" position="\(Int(width/2)) \(Int(height/2))">
<sublayers>
<CALayer allowsEdgeAntialiasing="1" allowsGroupOpacity="1" bounds="0 0 \(width) \(height)" contentsFormat="RGBA8" cornerCurve="circular" name="CALayer1" position="\(Int(width/2)) \(Int(height/2))">
<contents type="CGImage" src="assets/0.jpg"/>
<animations>
<animation type="CAKeyframeAnimation" calculationMode="linear" keyPath="contents" beginTime="1e-100" duration="\(animDur)" removedOnCompletion="0" repeatCount="inf" repeatDuration="0" speed="1" timeOffset="0" autoreverses="\(autoReverses ? 1 : 0)">
<values>
"""

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        )
        reader.add(readerOutput)
        reader.startReading()

        var frameCount = 0
        while let sampleBuffer = readerOutput.copyNextSampleBuffer(),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            try? autoreleasepool {
                let name = "\(frameCount).jpg"
                UIApplication.shared.change(
                    title: "Generating Video...",
                    body: "Creating \(name)..."
                )
                let ciImage = CIImage(cvPixelBuffer: imageBuffer).transformed(by: preferredTransform)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
                   let img = cgImage.jpg {
                    try? img.write(to: assetsFolder.appendingPathComponent(name))
                    camlData += "\t\t\t<CGImage src=\"assets/\(name)\"/>\n"
                    frameCount += 1
                }
            }
        }

        UIApplication.shared.change(title: "Generating Video...", body: "Creating CAML data...")

        camlData += """
        </values>
        </animation>
      </animations>
    </CALayer>
  </sublayers>
    </CATransformLayer>
  </sublayers>
  <states>
    <LKState name="Locked"><elements/></LKState>
    <LKState name="Unlock"><elements/></LKState>
    <LKState name="Sleep"><elements/></LKState>
  </states>
  <stateTransitions>
    <LKStateTransition fromState="*" toState="Unlock"><elements/></LKStateTransition>
    <LKStateTransition fromState="Unlock" toState="*"><elements/></LKStateTransition>
    <LKStateTransition fromState="*" toState="Locked"><elements/></LKStateTransition>
    <LKStateTransition fromState="Locked" toState="*"><elements/></LKStateTransition>
    <LKStateTransition fromState="*" toState="Sleep"><elements/></LKStateTransition>
    <LKStateTransition fromState="Sleep" toState="*"><elements/></LKStateTransition>
  </stateTransitions>
</CALayer>
</caml>
"""

        try camlData.data(using: .utf8)?
            .write(to: coreAnimDir.appendingPathComponent("main.caml"))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>assetManifest</key><string>assetManifest.caml</string>
            <key>documentHeight</key><real>\(height)</real>
            <key>documentResizesToView</key><true/>
            <key>documentWidth</key><real>\(width)</real>
            <key>dynamicGuidesEnabled</key><true/>
            <key>geometryFlipped</key><false/>
            <key>guidesEnabled</key><true/>
            <key>interactiveMouseEventsEnabled</key><true/>
            <key>interactiveShowsCursor</key><true/>
            <key>interactiveTouchEventsEnabled</key><false/>
            <key>loopEnd</key><real>0.0</real>
            <key>loopStart</key><real>0.0</real>
            <key>loopingEnabled</key><false/>
            <key>multitouchDisablesMouse</key><false/>
            <key>multitouchEnabled</key><false/>
            <key>presentationMouseEventsEnabled</key><true/>
            <key>presentationShowsCursor</key><true/>
            <key>presentationTouchEventsEnabled</key><false/>
            <key>rootDocument</key><string>main.caml</string>
            <key>savesWindowFrame</key><false/>
            <key>scalesToFitInPlayer</key><true/>
            <key>showsTouches</key><true/>
            <key>snappingEnabled</key><true/>
            <key>timelineMarkers</key><string>[(null)]</string>
            <key>touchesColor</key><string>1 1 0 0.8</string>
            <key>unitsInPixelsInPlayer</key><true/>
        </dict>
        </plist>
        """
        try xml.data(using: .utf8)?
            .write(to: coreAnimDir.appendingPathComponent("index.xml", conformingTo: .xml))

        return descrURL
    }
}
