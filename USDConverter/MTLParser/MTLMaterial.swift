//
//  MTLMaterial.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa

// only has the properties used in Apple Model I/O MTL files
// this is not a general .mtl parser
class MTLMaterial {

	var name: String
	private var properties: [MTLLineType: Double]

	init(materialName: String) {
		self.name = materialName
		self.properties = [:]
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
