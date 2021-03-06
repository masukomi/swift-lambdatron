//
//  InterpreterTest.swift
//  Lambdatron
//
//  Created by Austin Zheng on 1/16/15.
//  Copyright (c) 2015 Austin Zheng. All rights reserved.
//

import Foundation
import XCTest

/// Convenience function: given a bunch of ConsValues, return a list.
func listWithItems(items: ConsValue...) -> ConsValue {
  let list = listFromCollection(items, prefix: nil, postfix: nil)
  return .List(list)
}

/// Convenience functions: given a bunch of ConsValues, return a vector.
func vectorWithItems(items: ConsValue...) -> ConsValue {
  return .Vector(items)
}

/// Convenience function: given a bunch of ConsValue key-value pairs, return a map.
func mapWithItems(items: (ConsValue, ConsValue)...) -> ConsValue {
  if items.count == 0 {
    return .Map([:])
  }
  var buffer : MapType = [:]
  for (key, value) in items {
    buffer[key] = value
  }
  return .Map(buffer)
}

/// An abstract superclass intended for various interpreter tests.
class InterpreterTest : XCTestCase {
  var interpreter = Interpreter()

  override func setUp() {
    super.setUp()
    interpreter.reset()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    super.tearDown()
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  // Run some input, expecting no errors.
  func runCode(input: String) -> ConsValue? {
    let result = interpreter.evaluate(input)
    switch result {
    case let .Success(s):
      return s
    default:
      XCTFail("runCode did not successfully evaluate the input code")
      return nil
    }
  }

  /// Given an input string, evaluate it and compare the output to an expected ConsValue output.
  func expectThat(input: String, shouldEvalTo expected: ConsValue) {
    let result = interpreter.evaluate(input)
    switch result {
    case let .Success(actual):
      XCTAssert(expected == actual, "expected: \(expected), got: \(actual)")
    case let .ReadFailure(f):
      XCTFail("read error: \(f.description)")
    case let .EvalFailure(f):
      XCTFail("evaluation error: \(f.description)")
    }
  }

  /// Given an input string and a string describing an expected form, evaluate both and compare for equality.
  func expectThat(input: String, shouldEvalTo form: String) {
    // Evaluate the test form first
    let actual = interpreter.evaluate(input)
    switch actual {
    case let .Success(actual):
      // Then evaluate the reference form
      let expected = interpreter.evaluate(form)
      switch expected {
      case let .Success(expected):
        XCTAssert(expected == actual, "expected: \(expected), got: \(actual)")
      default:
        XCTFail("reference form failed to evaluate successfully; this is a problem with the unit test")
      }
    case let .ReadFailure(f):
      XCTFail("read error: \(f.description)")
    case let .EvalFailure(f):
      XCTFail("evaluation error: \(f.description)")
    }
  }

  /// Given an input string, evaluate it and expect a particular read failure.
  func expectThat(input: String, shouldFailAs expected: ReadError.ErrorType) {
    let result = interpreter.evaluate(input)
    switch result {
    case let .Success(s):
      XCTFail("evaluation unexpectedly succeeded; result: \(s.description)")
    case let .ReadFailure(actual):
      let expectedName = expected.rawValue
      let actualName = actual.error.rawValue
      XCTAssert(expected == actual.error, "expected: \(expectedName), got: \(actualName)")
    case .EvalFailure:
      XCTFail("evaluation error; shouldn't even get here")
    }
  }

  /// Given an input string, evaluate it and expect a particular evaluation failure.
  func expectThat(input: String, shouldFailAs expected: EvalError.ErrorType) {
    let result = interpreter.evaluate(input)
    switch result {
    case let .Success(s):
      XCTFail("evaluation unexpectedly succeeded; result: \(s.description)")
    case .ReadFailure:
      XCTFail("read error")
    case let .EvalFailure(actual):
      let expectedName = expected.rawValue
      let actualName = actual.error.rawValue
      XCTAssert(expected == actual.error, "expected: \(expectedName), got: \(actualName)")
    }
  }

  /// Given an input string, evaluate it and expect an arity error.
  func expectArityErrorFrom(input: String) {
    expectThat(input, shouldFailAs: .ArityError)
  }

  // Buffer functionality
  /// A buffer capturing output from the interpreter.
  var outputBuffer : String = ""

  /// Clear the output buffer.
  func clearOutputBuffer() {
    outputBuffer = ""
  }

  /// Write to the output buffer. Intended to be passed to the interpreter for use in testing println and side effects.
  func writeToBuffer(item: String) {
    outputBuffer += item
  }

  /// Compare an input string to the contents of the output buffer.
  func expectOutputBuffer(toBe expected: String) {
    XCTAssert(outputBuffer == expected, "expected: \(expected), got: \(outputBuffer)")
  }
}
