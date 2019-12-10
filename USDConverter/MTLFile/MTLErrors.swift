//
//  MTLErrors.swift
//  USDConverter
//
//  Created by Emma Alyx Wunder on 10.12.19.
//  Copyright © 2019 Emma Alyx Wunder. All rights reserved.
//

import Cocoa

struct MTLError: Error {
	enum ErrorKind {
		case meshConversionError
		case submeshConversionError
	}

	let kind: ErrorKind
	let message: String
	let innerError: Error?

	init(kind: ErrorKind, message: String, innerError: Error? = nil) {
		self.kind = kind

		self.message = message

		self.innerError = innerError
	}
}
