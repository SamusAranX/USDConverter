//
//  main.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 11.06.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Foundation
import ModelIO

let version = "1.1.1"
print("usdconv v\(version)")

let inputFilePaths = CommandLine.arguments.dropFirst()
guard inputFilePaths.count != 0 else {
	print("You need to specify at least one file to convert.")
	exit(1)
}

var failedConversions: [String] = []
for inFile in inputFilePaths {
	let model = URL(fileURLWithPath: inFile)

	guard MDLAsset.canImportFileExtension(model.pathExtension) else {
		failedConversions.append(model.lastPathComponent)
		continue
	}

	let modelDir = model.deletingLastPathComponent()
	let modelOut = model.deletingPathExtension().lastPathComponent + ".obj"
	let mtlOut = model.deletingPathExtension().lastPathComponent + "_aux.mtl"
	let mtlTarget = URL(fileURLWithPath: mtlOut, relativeTo: modelDir)
	let auxOut = model.deletingPathExtension().lastPathComponent + "_aux.txt"
	let auxTarget = URL(fileURLWithPath: auxOut, relativeTo: modelDir)
	let asset = MDLAsset(url: model)

	do {
		print("Converting \(model.lastPathComponent)…")
		let objTarget = URL(fileURLWithPath: modelOut, relativeTo: modelDir)
		try asset.export(to: objTarget)

		print("Generating \(mtlTarget.lastPathComponent)…")
		let modelFile = try ModelFile(modelFile: model)
		let mtlContent = modelFile.generateMTL()
		try mtlContent.write(to: mtlTarget, atomically: false, encoding: .utf8)

		print("Generating \(auxTarget.lastPathComponent)…")
		let sameMaterials = Dictionary(grouping: modelFile.materials, by: { $0 })
		let sortedDict = sameMaterials.sorted(by: {$0.1.count > $1.1.count})
		var auxString = "# Auxiliary USDConverter File\n\n"

		auxString.append("\(sortedDict.count) materials in total\n\n")

		for kvi in sortedDict {
			let occurrenceStr = kvi.value.count == 1 ? "occurrence" : "occurrences"
			auxString.append("\(kvi.value.count) \(occurrenceStr): \(kvi.key.name)\n")
			for material in kvi.value.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
				auxString.append("\(material.name)\n")
			}
			auxString.append("\n")
		}

		try auxString.trimmingCharacters(in: .whitespacesAndNewlines).write(to: auxTarget, atomically: false, encoding: .utf8)
		
		print("\(model.lastPathComponent) exported to \(objTarget.lastPathComponent)")
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
