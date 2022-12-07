//
//  ModelFile.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa
import ModelIO

class ModelFile {

	let file: URL
	var materials: [ModelMaterial]

	private var asset: MDLAsset

	init(modelFile: URL) throws {
		self.file = modelFile
		self.materials = []

		self.asset = MDLAsset(url: self.file)
		self.asset.loadTextures()

		var childIndex = 1
		for obj in self.asset.childObjects(of: MDLMesh.self) {
			guard let mesh = obj as? MDLMesh else {
				print("mesh conversion failed")
				continue
			}

			for rawSubmesh in mesh.submeshes ?? [] {
				guard let submesh = rawSubmesh as? MDLSubmesh else {
					print("submesh conversion failed")
					continue
				}

				guard let material = submesh.material else {
					continue
				}

				let materialName = "material_\(childIndex)"
				let mtlMaterial = ModelMaterial(materialName: materialName, originalMaterial: material, assetURL: self.asset.url)
				self.materials.append(mtlMaterial)

				childIndex += 1
			}
		}
	}

	func generateMTL(_ convertToPNG: Bool, excludeMaterials: [String]) -> String {
		var mtlString = "# USDConverter MTL File: \(file.deletingPathExtension().lastPathComponent).mtl\n"
		if !excludeMaterials.isEmpty {
			mtlString.append("# \(excludeMaterials.count) duplicate materials have been omitted\n")
		}
		mtlString.append("\n")

		for material in self.materials.filter({ !excludeMaterials.contains($0.name) }) {
			mtlString.append(material.generateMTL(includeMaterialName: true, convertToPNG: convertToPNG) + "\n\n")
		}
		return mtlString.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func extractTextures(_ convertToPNG: Bool, outputDirectory: URL) -> Bool {
		var alreadySaved: [URL] = []

		for material in self.materials {
			for semantic in ModelMaterial.allSemantics {
				guard let materialProp = material.get(semantic),
					let texturePath = materialProp.stringValue,
					let textureSampler = materialProp.textureSamplerValue else {
						continue
				}

				let texturePathParsed = ModelMaterial.parseTexturePath(texturePath)
				var urlComponents = URL(fileURLWithPath: texturePathParsed).pathComponents

				let textureFileName = urlComponents.popLast()!
				let textureOutDir = urlComponents.popLast()!

				var textureURL = outputDirectory.appending(component: textureOutDir).appending(component: textureFileName)

				guard let texture = textureSampler.texture else {
					continue
				}

				let cgImage = texture.imageFromTexture()!.takeRetainedValue()
				let nsBitmap = NSBitmapImageRep(cgImage: cgImage)

				var imageType: NSBitmapImageRep.FileType
				if convertToPNG {
					// override automatic selection here
					imageType = .png
					textureURL = textureURL.deletingPathExtension().appendingPathExtension("png")
				} else {
					let textureType = textureURL.pathExtension.lowercased()
					switch(textureType) {
						case "png":
							imageType = .png
						case "jpg", "jpeg":
							imageType = .jpeg
						default:
							// setting imageType to .png seems to make textures convertable, so ???
							imageType = .png
					}
				}

				guard !alreadySaved.contains(textureURL) else {
					continue
				}

				do {
					try FileManager.default.createDirectory(at: textureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				} catch {
					print("Couldn't create output directory")
					print(error)
					return false
				}

				let imageData = nsBitmap.representation(using: imageType, properties: [
					NSBitmapImageRep.PropertyKey.compressionFactor: NSNumber(floatLiteral: 1.0) // only used for JPEG files, disables compression
				])!

				do {
					try imageData.write(to: textureURL)
					alreadySaved.append(textureURL)
				} catch {
					print("Couldn't save \(textureURL.lastPathComponent)")
					return false
				}
			}
		}

		return true
	}

}

