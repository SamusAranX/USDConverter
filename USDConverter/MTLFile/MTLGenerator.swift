//
//  MTLGenerator.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa
import ModelIO

class MTLGenerator {

	static func generateMTL(for assetURL: URL) -> String {
		let asset = MDLAsset(url: assetURL)

		let allSemantics: [MDLMaterialSemantic] = [
			.baseColor, .emission, .specular, .opacity, .ambientOcclusion, .ambientOcclusionScale, .subsurface, .metallic, .specularTint,
			.roughness, .anisotropic, .anisotropicRotation, .sheen, .sheenTint, .clearcoat, .clearcoatGloss
		]
		let allSemanticsMTL = [
			"Kd", "Ka", "Ks", "d", "ao", "aoScale", "subsurface", "metallic", "specularTint", "roughness",
			"anisotropic", "anisotropicRotation", "sheen", "sheenTint", "clearCoat", "clearCoatGloss"
		]
		let forceExtendedFormat = [
			"Kd", "Ka", "Ks"
		]

		var mtlFileContents = ""

		let nf = NumberFormatter()
		nf.locale = Locale.init(identifier: "en_US")
		nf.numberStyle = .decimal
		nf.maximumFractionDigits = 5

		var childIndex = 1
		for obj in asset.childObjects(of: MDLMesh.self) {
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

				mtlFileContents.append("newmtl material_\(childIndex)\n")

				for idx in 0..<allSemantics.count {
					let matSemantic = allSemantics[idx]
					let semanticName = allSemanticsMTL[idx]

					if let property = material.property(with: matSemantic) {
						let fl = property.float3Value
						let num = [NSNumber(value: fl[0]), NSNumber(value: fl[1]), NSNumber(value: fl[2])]

						var propertyStringValue = nf.string(from: num[0])!
						if forceExtendedFormat.contains(semanticName) {
							propertyStringValue = "\(nf.string(from: num[0])!) \(nf.string(from: num[1])!) \(nf.string(from: num[2])!)"
						}

						// append the non-map value first to avoid "overwriting" it
						mtlFileContents.append("\t\(semanticName) \(propertyStringValue)\n")

						// check if a texture value is specified and if it is, append its filename
						if property.textureSamplerValue != nil, let propertyValue = property.stringValue {
							var texturePath = URL(fileURLWithPath: propertyValue).absoluteString.removingPercentEncoding!
							let modelDir = assetURL.deletingLastPathComponent().absoluteString.removingPercentEncoding!
							if let dirRange = texturePath.range(of: modelDir) {
								texturePath.removeSubrange(dirRange)
							}

							mtlFileContents.append("\tmap_\(semanticName) \(texturePath)\n")
						}
					}
				}

				mtlFileContents.append("\n")
			}

			childIndex += 1
		}

		return mtlFileContents
	}

}
