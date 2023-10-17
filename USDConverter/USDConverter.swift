//
//  USDConverter.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 11.06.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO

class USDConverter {

	static let version = "1.7"
	static var fullVersion: String? {
		get {
			guard let binaryPath = CommandLine.arguments.first else {
				return nil
			}

			let binaryName = URL(fileURLWithPath: binaryPath).lastPathComponent
			return "\(binaryName) \(version)"
		}
	}

	static var objcTrue: ObjCBool = true
	static var objcFalse: ObjCBool = false

	static func run(options: Main) {
		if options.png {
			print("* Will convert all textures to PNG")
		}

		if options.force {
			print("* Will attempt conversion for unsupported input file types")
		}

		if let checkOutDir = options.outputDirectory {
			if !FileManager.default.fileExists(atPath: checkOutDir, isDirectory: &objcTrue) {
				print("Error: Specified output directory \"\(checkOutDir)\" does not exist.")
				exit(1)
			}

			print("* Will output all files to \(checkOutDir)")
		}

		// MARK: Begin conversion

		for inFile in options.input {
			let model = URL(fileURLWithPath: inFile)
			let modelExt = model.pathExtension.lowercased()

			if !FileManager.default.fileExists(atPath: inFile) {
				print("Error opening \(model.lastPathComponent): File not found.")
				continue
			}

			let fileIsSceneKit = modelExt == "scn" || modelExt == "scnz"
			let fileIsUSDZ = modelExt == "usdz"

			let modelIsImportable = MDLAsset.canImportFileExtension(modelExt)

			if !fileIsUSDZ && !fileIsSceneKit && !options.force {
				print("Error opening \(model.lastPathComponent): usdconv can only open USDZ and SceneKit files.")
				continue
			}

			if !modelIsImportable && !fileIsSceneKit {
				print("Error opening \(model.lastPathComponent): Model I/O can't open this type of file.")
				continue
			}

			var outputDir = model.deletingLastPathComponent()
			if let outDir = options.outputDirectory {
				outputDir = URL(filePath: outDir, directoryHint: .isDirectory)
			}

			let modelBase = model.deletingPathExtension().lastPathComponent

			let modelObj   = "\(modelBase).obj"
			let modelMtl   = "\(modelBase).mtl"
			let garbageObj = "\(modelBase)_ModelIO.obj"
			let garbageMtl = "\(modelBase)_ModelIO.mtl"
			let modelInfo  = "\(modelBase)_duplicates.txt"

			let modelObjURL   = URL(fileURLWithPath: modelObj, relativeTo: outputDir)
			let modelMtlURL   = URL(fileURLWithPath: modelMtl, relativeTo: outputDir)
			let garbageObjURL = URL(fileURLWithPath: garbageObj, relativeTo: outputDir)
			let garbageMtlURL = URL(fileURLWithPath: garbageMtl, relativeTo: outputDir)
			let modelInfoURL  = URL(fileURLWithPath: modelInfo, relativeTo: outputDir)

			var asset: MDLAsset

			if fileIsSceneKit {
				print("\(model.lastPathComponent): SceneKit scene detected. Attempting to convert…")

				guard let scene = try? SCNScene(url: model, options: nil) else {
					print("Error opening \(model.lastPathComponent): Invalid SceneKit file.")
					continue
				}

				asset = MDLAsset(scnScene: scene)
			} else {
				asset = MDLAsset(url: model)
			}

			if asset.frameInterval != 0 && asset.endTime - asset.startTime > 0.05 {
				print("NOTE: This asset contains animation information that will be discarded in the conversion to OBJ.")
			}

			// MARK: - Converting USDZ to OBJ and generating Model I/O MTL file

			print("Converting \(model.lastPathComponent)…")

			do {
				try asset.export(to: garbageObjURL)
			} catch {
				print("Couldn't convert \(model.lastPathComponent).")
				continue
			}

			if !modelIsImportable {
				continue
			}

			// MARK: - De-duplicating materials

			print("Filtering out duplicate materials from \(modelObj)…")

			guard let modelFile = try? ModelFile(modelFile: model) else {
				print("Couldn't convert \(model.lastPathComponent).")
				continue
			}
			let materialCountDict = Dictionary(grouping: modelFile.materials, by: { $0 })
			let sortedMaterialCount = materialCountDict.sorted(by: {$0.1.count > $1.1.count})

			// MARK: - Generating list of duplicates

			print("Generating list of duplicates…")

			var auxString = "# USDConverter List Of Duplicate Materials: \(modelObj)\n"
			auxString.append("\(sortedMaterialCount.count) distinct materials in total\n\n")

			for kvi in sortedMaterialCount {
				let occurrenceStr = kvi.value.count == 1 ? "occurrence" : "occurrences"
				auxString.append("\(kvi.key.name): \(kvi.value.count) \(occurrenceStr)\n")
			}

			// MARK: - De-duplicate OBJ materials

			print("Correcting OBJ material references…")

			guard let objContents = try? String(contentsOf: garbageObjURL, encoding: .utf8) else {
				print("Couldn't read \(garbageObj)")
				continue
			}

			var usedMaterials: [ModelMaterial] = []
			var newObjContents: [String] = []
			objContents.enumerateLines(invoking: { line, _ in
				if line.starts(with: "mtllib") {
					newObjContents.append("mtllib \(modelMtl)")
					return
				} else if line.starts(with: "# Apple ModelIO OBJ File") {
					newObjContents.append("# USDConverter OBJ File: \(modelObjURL.deletingPathExtension().lastPathComponent).obj")
					return
				}

				guard line.starts(with: "usemtl ") else {
					newObjContents.append(line)
					return
				}

				let matName = String(line.trimmingPrefix("usemtl "))
				guard let matMatch = materialCountDict.first(where: { 
					(_: ModelMaterial, duplicates: [ModelMaterial]) -> Bool in
					return duplicates.map({ $0.name }).contains(matName)
				}) else {
					return
				}

				usedMaterials.append(matMatch.key)
				newObjContents.append("usemtl \(matMatch.key.simpleName)")
			})

			usedMaterials = Array(Set(usedMaterials)).sorted(by: { $0.simpleName.localizedStandardCompare($1.simpleName) == .orderedAscending })

			// MARK: - Writing corrected files

			print("Writing OBJ file: \(modelObj)")
			do {
				try newObjContents.joined(separator: "\n").write(to: modelObjURL, atomically: true, encoding: .utf8)
			} catch {
				print("Couldn't write \(modelObj)")
				continue
			}

			print("Writing MTL file: \(modelMtl)…")
			let mtlContents = modelFile.generateMTL(options.png, usedMaterials: usedMaterials)
			do {
				try mtlContents.write(to: modelMtlURL, atomically: true, encoding: .utf8)
			} catch {
				print("Couldn't write \(modelMtl)")
				continue
			}

			if options.includeGarbage {
				print("Writing list of duplicates: \(modelInfo)…")
				do {
					let outputStr = auxString.trimmingCharacters(in: .whitespacesAndNewlines)
					try outputStr.write(to: modelInfoURL, atomically: true, encoding: .utf8)
				} catch {
					print("Couldn't write \(modelInfo)")
					continue
				}
			}

			// MARK: - Extracting textures

			print("Extracting textures…")
			if !modelFile.extractTextures(options.png, outputDirectory: outputDir) {
				print("Couldn't extract textures")
			}

			// MARK: - Optional cleanup

			if !options.includeGarbage {
				print("Deleting Model I/O garbage…")
				do {
					try FileManager.default.removeItem(at: garbageObjURL)
					try FileManager.default.removeItem(at: garbageMtlURL)
				} catch {
					print("Couldn't delete Model I/O garbage")
				}
			}

			print("Exported \(model.lastPathComponent) to \(modelObj)")
		}

		print("Done.")
	}

}

