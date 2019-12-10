//
//  MTLMaterial.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa
import ModelIO

// only has the properties used in Apple Model I/O MTL files
// this is not a general .mtl parser
class MTLMaterial: Equatable {

	var name: String
	private var properties: [MTLLineType: Double]

	private let allSemantics: [MDLMaterialSemantic] = [
		.baseColor, .emission, .specular, .opacity, .ambientOcclusion, .ambientOcclusionScale, .subsurface, .metallic, .specularTint,
		.roughness, .anisotropic, .anisotropicRotation, .sheen, .sheenTint, .clearcoat, .clearcoatGloss
	]
	private let allSemanticsMTL = [
		"Kd", "Ka", "Ks", "d", "ao", "aoScale", "subsurface", "metallic", "specularTint", "roughness",
		"anisotropic", "anisotropicRotation", "sheen", "sheenTint", "clearCoat", "clearCoatGloss"
	]
	private let forceExtendedFormat = [
		"Kd", "Ka", "Ks"
	]

	init(materialName: String) {
		self.name = materialName
		self.properties = [:]
	}

	static func == (lhs: MTLMaterial, rhs: MTLMaterial) -> Bool {
		return false
	}

	func set(property: String, value: Double) {
		guard let lineType = MTLLineType.init(rawValue: property) else {
			print("Unknown property \"\(property)\"")
			return
		}

		self.properties[lineType] = value
	}

	func get(property: MTLLineType) -> Double? {
		if let value = self.properties[property] {
			return value
		}

		print("Property \"\(property.rawValue)\" not found")
		return nil
	}

}
