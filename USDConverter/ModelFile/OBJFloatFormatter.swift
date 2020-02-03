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
		self.nf.maximumFractionDigits = 5
	}

	func string(for float: Float) -> String {
		return self.nf.string(for: float)!
	}

	func string(for floatStr: String) -> String? {
		defer {
			self.nf.maximumFractionDigits = 5
		}

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

		return self.string(for: float)
	}
}
