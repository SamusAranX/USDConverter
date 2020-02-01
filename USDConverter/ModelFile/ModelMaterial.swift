//
//  ModelMaterial.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa
import ModelIO

// only has the properties used in Apple Model I/O MTL files
// this is not a general .mtl parser
class ModelMaterial: Hashable, CustomStringConvertible {

	struct MaterialValue: Hashable {
		var float3Value: SIMD3<Float>
		var stringValue: String? = nil
		var textureValue: MDLTextureSampler?

		var forceExtended: Bool

		init(materialProperty: MDLMaterialProperty?, forceExtended: Bool = false) {
			self.float3Value = SIMD3<Float>(0, 0, 0)

			if let materialProperty = materialProperty {
				self.float3Value  = materialProperty.float3Value
				self.stringValue  = materialProperty.stringValue
				self.textureValue = materialProperty.textureSamplerValue
			}

			self.forceExtended = forceExtended
		}

		static func == (lhs: MaterialValue, rhs: MaterialValue) -> Bool {
			if lhs.stringValue != nil && rhs.stringValue != nil {
				return lhs.stringValue == rhs.stringValue
			}

			if lhs.textureValue != nil && rhs.textureValue != nil {
				return lhs.textureValue == rhs.textureValue
			}

			return lhs.formattedFloat == rhs.formattedFloat
		}

		fileprivate var formattedFloat: String {
			let nf = NumberFormatter()
			nf.locale = Locale.init(identifier: "en_US")
			nf.numberStyle = .decimal
			nf.maximumFractionDigits = 5

			let nums = [NSNumber(value: float3Value[0]), NSNumber(value: float3Value[1]), NSNumber(value: float3Value[2])]

			if self.forceExtended {
				return "\(nf.string(from: nums[0])!) \(nf.string(from: nums[1])!) \(nf.string(from: nums[2])!)"
			} else {
				return nf.string(from: nums[0])!
			}
		}
	}

	var name: String
	private let internalMaterial: MDLMaterial?
	private var assetURL: URL?

	static let allSemantics: [MDLMaterialSemantic] = [
		.baseColor, .emission, .specular, .opacity, .ambientOcclusion, .subsurface, .metallic, .specularTint,
		.roughness, .anisotropic, .anisotropicRotation, .sheen, .sheenTint, .clearcoat, .clearcoatGloss, .tangentSpaceNormal
	]
	static let allSemanticsMTL = [
		"Kd", "Ka", "Ks", "d", "ao", "subsurface", "metallic", "specularTint", "roughness",
		"anisotropic", "anisotropicRotation", "sheen", "sheenTint", "clearCoat", "clearCoatGloss", "tangentSpaceNormal"
	]
	static var allSemanticsDict: [MDLMaterialSemantic: String] {
		return Dictionary(uniqueKeysWithValues: zip(ModelMaterial.allSemantics, ModelMaterial.allSemanticsMTL))
	}

	private let forceExtendedProperties = [
		"Kd", "Ka", "Ks"
	]

	var description: String {
		return self.generateMTL()
	}

	init(materialName: String, originalMaterial: MDLMaterial?, assetURL: URL?) {
		self.name = materialName
		self.internalMaterial = originalMaterial
		self.assetURL = assetURL
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(self.generateMTL(includeMaterialName: false))
	}

	static func == (lhs: ModelMaterial, rhs: ModelMaterial) -> Bool {
		for semantic in ModelMaterial.allSemantics {
			let leftSideValue = MaterialValue(materialProperty: lhs.get(semantic))
			let rightSideValue = MaterialValue(materialProperty: rhs.get(semantic))

			if leftSideValue != rightSideValue {
				return false
			}
		}

		return true
	}

	func get(_ semantic: MDLMaterialSemantic) -> MDLMaterialProperty? {
		guard let prop = self.internalMaterial?.property(with: semantic) else {
			return nil
		}

		return prop
	}

	static func parseTexturePath(_ texturePath: String) -> String {
		do {
			let pattern = #"^.*?(.*?)\.usdz\[(.*?)\]$"#
			let regex = try NSRegularExpression(pattern: pattern, options: [])
			let nsRange = NSRange(texturePath.startIndex..<texturePath.endIndex, in: texturePath)

			if let match = regex.firstMatch(in: texturePath, options: [], range: nsRange),
				let filenameRange = Range(match.range(at: 1), in: texturePath),
				let textureRange = Range(match.range(at: 2), in: texturePath) {

				let modelPath = String(texturePath[filenameRange])
				let textureFile = URL(fileURLWithPath: String(texturePath[textureRange])).lastPathComponent

				return "\(modelPath)/\(textureFile)"
			}
		} catch {
			return texturePath
		}

		return texturePath
	}

	func generateMTL(includeMaterialName: Bool = true, convertToPNG: Bool = false) -> String {
		var tempString = ""

		if includeMaterialName {
			tempString = "newmtl \(name)\n"
		}

		for semantic in ModelMaterial.allSemantics {
			if let propertyValue = self.get(semantic) {
				let semanticName = ModelMaterial.allSemanticsDict[semantic] ?? ""
				let materialValue = MaterialValue(materialProperty: propertyValue, forceExtended: self.forceExtendedProperties.contains(semanticName))

				if let stringValue = materialValue.stringValue, let assetURL = assetURL {
					var texturePath = URL(fileURLWithPath: stringValue).absoluteString.removingPercentEncoding!
					let modelDir = assetURL.deletingLastPathComponent().absoluteString.removingPercentEncoding!
					if let dirRange = texturePath.range(of: modelDir) {
						texturePath.removeSubrange(dirRange)
					}

					var texPath = ModelMaterial.parseTexturePath(texturePath)

					if convertToPNG {
						let texURL = URL(fileURLWithPath: texPath).deletingPathExtension().appendingPathExtension("png")
						texPath = texURL.relativeString
					}

					tempString.append("\tmap_\(semanticName) \(texPath)\n")
				} else {
					tempString.append("\t\(semanticName) \(materialValue.formattedFloat)\n")
				}
			}
		}

		return tempString.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
