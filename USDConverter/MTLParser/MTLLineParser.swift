//
//  MTLLineParser.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa
import ModelIO

class MTLLineParser {
	static func parse(mtlFile: URL) throws -> MTLFile? {
		let fileContents = try String(contentsOf: mtlFile, encoding: .utf8)

		var tempMaterial: MTLMaterial
		for line in fileContents.split(whereSeparator: { $0.isNewline }) {
			let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespaces)
			if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
				continue
			}
		}

		return nil
	}
}
