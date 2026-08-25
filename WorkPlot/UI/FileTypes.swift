//
//  FileTypes.swift
//  WorkPlot
//
//  Declared UTIs for the app's custom file formats. The identifiers match
//  UTImportedTypeDeclarations in Info.plist - without that registration the
//  document picker treats unknown extensions as generic data and lets the
//  user select any file.
//

import UniformTypeIdentifiers

extension UTType {
    static let tendies = UTType("com.workplot.tendies")
        ?? UTType(filenameExtension: "tendies", conformingTo: .data)
        ?? .data
}
