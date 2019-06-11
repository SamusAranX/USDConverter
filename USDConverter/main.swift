//
//  main.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 11.06.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Foundation
import ModelIO

let version = "1.0.1"
print("usdconv v\(version)")

let inputFiles = CommandLine.arguments.dropFirst()
guard inputFiles.count != 0 else {
	fatalError("You need to specify at least one file to convert.")
}

var failedConversions: [String] = []
for inFile in inputFiles {
	let model = URL(fileURLWithPath: inFile)

	guard MDLAsset.canImportFileExtension(model.pathExtension) else {
		failedConversions.append(model.lastPathComponent)
		continue
	}

	let modelDir = model.deletingLastPathComponent()
	let modelOut = model.deletingPathExtension().lastPathComponent + ".obj"
	let asset = MDLAsset(url: model)

	do {
		let target = URL(fileURLWithPath: modelOut, relativeTo: modelDir)
		try asset.export(to: target)
		print("\(model.lastPathComponent) exported to \(target.lastPathComponent)")
	} catch {
		failedConversions.append(model.lastPathComponent)
	}
}

if failedConversions.count == 0 {
	print("All conversions successful.")
} else {
	print("The following files couldn't be converted:")
	for failed in failedConversions {
		print(failed)
	}
}
