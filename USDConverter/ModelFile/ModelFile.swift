//
//  ModelFile.swift
//  USDConverter
//
//  Created by Peter Wunder on 10.12.19.
//  Copyright © 2019 Peter Wunder. All rights reserved.
//

import Cocoa
import ModelIO

class ModelFile {

	private struct LineInfo {
		var prefix: String
		var values: Int
	}

	private let lineDefs: [String: LineInfo] = [
		MDLVertexAttributePosition: LineInfo(prefix: "v", values: 3),
		MDLVertexAttributeNormal: LineInfo(prefix: "vn", values: 3),
		MDLVertexAttributeTextureCoordinate: LineInfo(prefix: "vt", values: 2)
	]

	let file: URL
	var materials: [ModelMaterial]
	var submeshes: [MDLSubmesh]

	private var asset: MDLAsset

	init(modelFile: URL) throws {
		self.file = modelFile

		self.submeshes = []
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

				self.submeshes.append(submesh)

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

	func generateOBJ() -> String {
		var objString = "# USDConverter OBJ File: \(file.deletingPathExtension().lastPathComponent).obj\n"
		objString.append("mtllib \(file.deletingPathExtension().lastPathComponent).mtl\n")

		var submeshIndex = 0
		let off = OBJFloatFormatter()

		for obj in self.asset.childObjects(of: MDLMesh.self) {
			guard let mesh = obj as? MDLMesh else {
				print("mesh conversion failed")
				continue
			}

			let submesh = self.submeshes[submeshIndex]

			objString.append("g submesh_\(submeshIndex)\n")
			objString.append("usemtl material_\(submeshIndex)\n")

			print("submesh_\(submeshIndex)")

			for case let attr as MDLVertexAttribute in mesh.vertexDescriptor.attributes where attr.format != .invalid {
				let buf = mesh.vertexBuffers[attr.bufferIndex]
				let bufData = Data(bytes: buf.map().bytes, count: buf.length)

				switch(attr.format) {
				case .float, .float2, .float3, .float4:
					var array = Array<Float32>(repeating: 0, count: buf.length / MemoryLayout<Float32>.stride)
					_ = array.withUnsafeMutableBytes { bufData.copyBytes(to: $0) }

					guard let objDefs = self.lineDefs[attr.name] else {
						break
					}

					print(attr.name, array.count)

					for i in stride(from: 0, to: array.count, by: objDefs.values) {
						objString.append(objDefs.prefix)
						for j in 0..<objDefs.values {
							let idx = i + j
							objString.append(" \(off.string(for: array[idx]))")
						}
						objString.append("\n")
					}
				default:
					fatalError("Unknown format \(attr.format.rawValue)")
				}
			}

			let idxBuf = submesh.indexBuffer
			let idxBufData = Data(bytes: idxBuf.map().bytes, count: idxBuf.length)
			var array = Array<Int32>(repeating: 0, count: idxBuf.length / MemoryLayout<Int32>.stride)
			_ = array.withUnsafeMutableBytes { idxBufData.copyBytes(to: $0) }

			assert(idxBuf.length / submesh.indexCount == 4)

			objString.append("# INDICES: \(array.count)\n")

			for i in stride(from: 0, to: array.count, by: 3) {
				let v = array[i]
				let t = array[i+1]
				let n = array[i+2]

				objString.append("f \(v)/\(t)/\(n)\n")
			}

			print("tris", array.count)

			submeshIndex += 1

			print("----")

//			if submeshIndex == 1 {
//				break
//			}
		}

		return objString.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func extractTextures(_ convertToPNG: Bool) -> Bool {
		var alreadySaved: [URL] = []

		for material in self.materials {
			for semantic in ModelMaterial.allSemantics {
				guard let materialProp = material.get(semantic),
					let texturePath = materialProp.stringValue,
					let textureSampler = materialProp.textureSamplerValue else {
						continue
				}

				var textureURL = URL(fileURLWithPath: ModelMaterial.parseTexturePath(texturePath))
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

				guard let texture = textureSampler.texture else {
					continue
				}

				let cgImage = texture.imageFromTexture()!.takeRetainedValue()
				let nsBitmap = NSBitmapImageRep(cgImage: cgImage)

				var imageType: NSBitmapImageRep.FileType
				let textureType = textureURL.pathExtension.lowercased()

				switch(textureType) {
				case "png":
					imageType = .png
				case "jpg", "jpeg":
					imageType = .jpeg
				default:
					print("Unknown texture type \"\(textureType)\" of texture \(textureURL.lastPathComponent)")
					imageType = .png
				}

				if convertToPNG {
					// override automatic selection here
					imageType = .png
					textureURL = textureURL.deletingPathExtension().appendingPathExtension("png")
				}

				let imageData = nsBitmap.representation(using: imageType, properties: [
					NSBitmapImageRep.PropertyKey.compressionFactor: NSNumber(floatLiteral: 1.0)
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



