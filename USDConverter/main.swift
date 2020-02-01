//
//  main.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 11.06.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Foundation
import ModelIO

extension Sequence where Iterator.Element: Hashable {
	func unique() -> [Iterator.Element] {
		var seen: [Iterator.Element: Bool] = [:]
		return self.filter { seen.updateValue(true, forKey: $0) == nil }
	}
}

let version = "1.3"
print("usdconv v\(version)")

var inputFilePaths = CommandLine.arguments.dropFirst().unique()

var convertToPNG = false

if inputFilePaths.contains("--png") {
	convertToPNG = true
	inputFilePaths.removeAll(where: { $0 == "--png" })
	print("--png specified, will save all textures as PNG, even non-PNG ones")
}

guard inputFilePaths.count != 0 else {
	print("You need to specify at least one file to convert.")
	exit(1)
}

for inFile in inputFilePaths {
	let model = URL(fileURLWithPath: inFile)
	let modelExt = model.pathExtension.lowercased()

	guard modelExt == "usdz", MDLAsset.canImportFileExtension(modelExt) else {
		print("Error opening \(model.lastPathComponent): usdconf can only open USDZ files.")
		continue
	}

	let modelDir = model.deletingLastPathComponent()
	let modelBase = model.deletingPathExtension().lastPathComponent

	let modelObj   = "\(modelBase).obj"
	let modelIOObj = "\(modelBase)_ModelIO.obj"
	let modelMtl   = "\(modelBase).mtl"
//	let modelIOMtl = "\(modelBase)_ModelIO.mtl" // unused
	let modelInfo  = "\(modelBase)_duplicates.txt"

	let modelObjURL   = URL(fileURLWithPath: modelObj, relativeTo: modelDir)
	let modelIOObjURL = URL(fileURLWithPath: modelIOObj, relativeTo: modelDir)
	let modelMtlURL   = URL(fileURLWithPath: modelMtl, relativeTo: modelDir)
//	let modelIOMtlURL = URL(fileURLWithPath: modelIOMtl, relativeTo: modelDir) // unused
	let modelInfoURL  = URL(fileURLWithPath: modelInfo, relativeTo: modelDir)

	let asset = MDLAsset(url: model)

	// MARK: - Converting USDZ to OBJ and generating Model I/O MTL file

	print("Converting \(model.lastPathComponent)…")

	do {
		try asset.export(to: modelIOObjURL)
	} catch {
		print("Couldn't convert \(model.lastPathComponent).")
		continue
	}

	// MARK: - De-duplicating materials

	print("Filtering out duplicate materials from \(modelObj)…")

	let modelFile = try ModelFile(modelFile: model)
	let materialCountDict = Dictionary(grouping: modelFile.materials, by: { $0 })
	let sortedMaterialCount = materialCountDict.sorted(by: {$0.1.count > $1.1.count})

	// MARK: - Generating list of duplicates

	print("Generating list of duplicates…")

	var auxString = "# USDConverter List Of Duplicate Materials: \(modelObj)\n"
	auxString.append("\(sortedMaterialCount.count) distinct materials in total\n\n")

	var duplicateMaterialNames: [String] = []
	for kvi in sortedMaterialCount {
		let occurrenceStr = kvi.value.count == 1 ? "occurrence" : "occurrences"
		auxString.append("\(kvi.key.name): \(kvi.value.count) \(occurrenceStr)\n")

		for material in kvi.value.dropFirst().sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
			auxString.append("\t\(material.name)\n")
			duplicateMaterialNames.append(material.name)
		}

		auxString.append("\n")
	}

	// MARK: - De-duplicate OBJ materials

	print("Correcting OBJ material references…")

	guard let objContents = try? String(contentsOf: modelIOObjURL, encoding: .utf8) else {
		print("Couldn't read \(modelIOObj)")
		continue
	}

	var newObjContents: [String] = []
	objContents.enumerateLines(invoking: {
		line, _ in

		if line.starts(with: "mtllib") {
			newObjContents.append("mtllib \(modelMtl)")
			return
		}

		guard line.starts(with: "usemtl") else {
			newObjContents.append(line)
			return
		}

		let matName = line.dropFirst(7)
		let deduplicatedMatName = materialCountDict.filter({
			return $0.value.map({
				Substring($0.name) // Swift wants a Substring for some reason
			}).contains(matName)
		})[0].key.name

		newObjContents.append("usemtl \(deduplicatedMatName)")
	})

	// MARK: - Writing corrected files

	print("Writing OBJ file: \(modelObj)")
	do {
		try newObjContents.joined(separator: "\n").write(to: modelObjURL, atomically: true, encoding: .utf8)
	} catch {
		print("Couldn't write \(modelObj)")
	}

	print("Writing MTL file: \(modelMtl)…")
	let mtlContents = modelFile.generateMTL(convertToPNG, excludeMaterials: duplicateMaterialNames)
	do {
		try mtlContents.write(to: modelMtlURL, atomically: true, encoding: .utf8)
	} catch {
		print("Couldn't write \(modelMtl)")
		continue
	}

	print("Writing list of duplicates: \(modelInfo)…")
	do {
		let outputStr = auxString.trimmingCharacters(in: .whitespacesAndNewlines)
		try outputStr.write(to: modelInfoURL, atomically: true, encoding: .utf8)
	} catch {
		print("Couldn't write \(modelInfo)")
		continue
	}

	// MARK: - Extracting textures

	print("Extracting textures…")
	if !modelFile.extractTextures(convertToPNG) {
		print("Couldn't extract textures")
	}

	print("Exported \(model.lastPathComponent) to \(modelObj)")
}

print("Done.")
