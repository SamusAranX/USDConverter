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
class ModelMaterial: Hashable, Equatable, CustomStringConvertible {

	struct MaterialValue: Hashable, Equatable {
		var float3Value: SIMD3<Float>
		var stringValue: String? = nil

		var forceExtended: Bool

		init(materialProperty: MDLMaterialProperty?, forceExtended: Bool = false) {
			self.float3Value = SIMD3<Float>(0, 0, 0)

			if let materialProperty = materialProperty {
				self.float3Value = materialProperty.float3Value
				self.stringValue = materialProperty.stringValue
			}

			self.forceExtended = forceExtended
		}

		static func == (lhs: MaterialValue, rhs: MaterialValue) -> Bool {
			if lhs.stringValue != nil && rhs.stringValue != nil {
				return lhs.stringValue == rhs.stringValue
			}

			return lhs.float3Value == rhs.float3Value
		}

		fileprivate var formattedFloat: String {
			let nf = NumberFormatter()
			nf.locale = Locale.init(identifier: "en_US")
			nf.numberStyle = .decimal
			nf.maximumFractionDigits = 5

			let nums = [NSNumber(value: float3Value[0]), NSNumber(value: float3Value[1]), NSNumber(value: float3Value[2])]
//			let numsEqual = nums[0] == nums[1] && nums[1] == nums[2]

			if self.forceExtended {
				return "\(nf.string(from: nums[0])!) \(nf.string(from: nums[1])!) \(nf.string(from: nums[2])!)"
			} else {
				return nf.string(from: nums[0])!
			}
		}

		fileprivate func textureName(assetURL: URL) -> String? {
			guard let stringValue = stringValue else {
				return nil
			}

			let textureURL = URL(fileURLWithPath: stringValue)
			if let modelDir = assetURL.deletingLastPathComponent().absoluteString.removingPercentEncoding {
				var texturePath = textureURL.absoluteString.removingPercentEncoding!
				if let dirRange = texturePath.range(of: modelDir) {
					texturePath.removeSubrange(dirRange)
					return texturePath
				}
			}

			return textureURL.absoluteString.removingPercentEncoding
		}
	}

	var name: String
	private var internalMaterial: MDLMaterial?
	private var assetURL: URL?

	private static let allSemantics: [MDLMaterialSemantic] = [
		.baseColor, .emission, .specular, .opacity, .ambientOcclusion, .subsurface, .metallic, .specularTint,
		.roughness, .anisotropic, .anisotropicRotation, .sheen, .sheenTint, .clearcoat, .clearcoatGloss, .tangentSpaceNormal
	]
	private static let allSemanticsMTL = [
		"Kd", "Ka", "Ks", "d", "ao", "subsurface", "metallic", "specularTint", "roughness",
		"anisotropic", "anisotropicRotation", "sheen", "sheenTint", "clearCoat", "clearCoatGloss", "tangentSpaceNormal"
	]
	private var allSemanticDict: [String: MDLMaterialSemantic] {
		return Dictionary(uniqueKeysWithValues: zip(ModelMaterial.allSemanticsMTL, ModelMaterial.allSemantics))
	}

	private let forceExtendedProperties = [
		"Kd", "Ka", "Ks"
	]

	var description: String {
		return self.generateMTL(includeHeader: false)
	}

	init(materialName: String, originalMaterial: MDLMaterial?, assetURL: URL?) {
		self.name = materialName
		self.internalMaterial = originalMaterial
		self.assetURL = assetURL
	}

	func hash(into hasher: inout Hasher) {
		for semanticMTL in ModelMaterial.allSemanticsMTL {
			let matValue = MaterialValue(materialProperty: self.get(property: semanticMTL))
			hasher.combine(matValue)
		}
	}

	static func == (lhs: ModelMaterial, rhs: ModelMaterial) -> Bool {
		for semanticMTL in ModelMaterial.allSemanticsMTL {
			let leftSideValue = MaterialValue(materialProperty: lhs.get(property: semanticMTL))
			let rightSideValue = MaterialValue(materialProperty: rhs.get(property: semanticMTL))

			if leftSideValue != rightSideValue {
				return false
			}
		}

		return true
	}

	internal func get(property mtlName: String) -> MDLMaterialProperty? {
		guard let semantic = allSemanticDict[mtlName], let prop = self.internalMaterial?.property(with: semantic) else {
			return nil
		}

		return prop
	}

	func generateMTL(includeHeader: Bool = true) -> String {
		var tempString = ""
		tempString.append("newmtl \(name)\n")

		for semanticName in ModelMaterial.allSemanticsMTL {
			if let propertyValue = self.get(property: semanticName) {
				let materialValue = MaterialValue(materialProperty: propertyValue, forceExtended: self.forceExtendedProperties.contains(semanticName))

				if let stringValue = materialValue.stringValue, let assetURL = assetURL {
					var texturePath = URL(fileURLWithPath: stringValue).absoluteString.removingPercentEncoding!
					let modelDir = assetURL.deletingLastPathComponent().absoluteString.removingPercentEncoding!
					if let dirRange = texturePath.range(of: modelDir) {
						texturePath.removeSubrange(dirRange)
					}

					do {
						let pattern = #"^.*?(.*?)\.usdz\[(.*?)\]$"#
						let regex = try NSRegularExpression(pattern: pattern, options: [])
						let nsRange = NSRange(texturePath.startIndex..<texturePath.endIndex, in: texturePath)

						if let match = regex.firstMatch(in: texturePath, options: [], range: nsRange),
							let filenameRange = Range(match.range(at: 1), in: texturePath),
							let textureRange = Range(match.range(at: 2), in: texturePath) {

							let modelFile = String(texturePath[filenameRange])
							let textureFile = URL(fileURLWithPath: String(texturePath[textureRange])).lastPathComponent
							tempString.append("\tmap_\(semanticName) \(modelFile)/\(textureFile)\n")
						}
					} catch {
						tempString.append("\tmap_\(semanticName) \(texturePath)\n")
					}
				} else {
					tempString.append("\t\(semanticName) \(materialValue.formattedFloat)\n")
				}
			}
		}

		return tempString.trimmingCharacters(in: .whitespacesAndNewlines)
	}

}

// MARK: - Convenience properties
extension ModelMaterial {

	var Kd: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop, forceExtended: true)
	}

	var Ka: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop, forceExtended: true)
	}

	var Ks: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop, forceExtended: true)
	}

	var d: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var ao: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var aoScale: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var subsurface: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var metallic: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var specularTint: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var roughness: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var anisotropic: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var anisotropicRotation: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var sheen: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var sheenTint: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var clearCoat: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

	var clearCoatGloss: MaterialValue? {
		guard let prop = self.get(property: #function) else { return nil }
		return MaterialValue(materialProperty: prop)
	}

}
