//
//  OBJFloatFormatter.swift
//  USDConverter
//
//  Created by Peter Wunder on 01.02.20.
//  Copyright © 2020 Peter Wunder. All rights reserved.
//

import Cocoa

class OBJFloatFormatter {
	private var nf: NumberFormatter

	init() {
		self.nf = NumberFormatter()
		self.nf.localizesFormat = false
		self.nf.minimumIntegerDigits = 1
	}

	func string(for floatStr: String) -> String? {
		if floatStr.contains("e") {
			self.nf.maximumFractionDigits = 15
		} else if floatStr.contains(".") {
			self.nf.maximumFractionDigits = floatStr.split(separator: ".").last?.count ?? 0
		} else {
			self.nf.maximumFractionDigits = 2
		}

		guard let float = Float(floatStr) else {
			return nil
		}

		return self.nf.string(for: float)
	}
}
