//
//  TestFnPosition.swift
//  Lambdatron
//
//  Created by Austin Zheng on 1/16/15.
//  Copyright (c) 2015 Austin Zheng. All rights reserved.
//

import Foundation

/// Test the use of functions and special forms in function position.
class TestFnPositionFnsSpecialForms : InterpreterTest {

  /// A function literal without arguments should be recognized as a function in function position.
  func testFunctionLiteral() {
    expectThat("((fn [] \"foobar\"))", shouldEvalTo: .StringLiteral("foobar"))
  }

  /// A function literal with arguments should be recognized as a function in function position.
  func testFunctionLiteralWithArgs() {
    expectThat("((fn [a b c] (.+ (.* a b) c)) 15 8 -4)", shouldEvalTo: .IntegerLiteral(116))
  }

  /// A function bound to a symbol should evaluate properly.
  func testFunctionLiteralSymbol() {
    runCode("(def testFunc (fn [a b c] (.+ a (.+ b c))))")
    expectThat("(testFunc 1 15 1000)", shouldEvalTo: .IntegerLiteral(1016))
  }

  /// A built-in in function should evaluate properly.
  func testBuiltInFunction() {
    expectThat("(.+ 15 89)", shouldEvalTo: .IntegerLiteral(104))
  }

  /// A built-in function bound to a symbol should evaluate properly.
  func testBuiltInFunctionSymbol() {
    runCode("(def testPlus .+)")
    expectThat("(testPlus 15 89)", shouldEvalTo: .IntegerLiteral(104))
  }

  /// A special form should evaluate properly.
  func testSpecialForm() {
    expectThat("(if true 9001 1009)", shouldEvalTo: .IntegerLiteral(9001))
  }
}

/// Test the use of vectors in function position.
class TestFnPositionVectors : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A vector in function position with a valid index should extract the proper value from the vector.
  func testValidIndex() {
    expectThat("([100 200 300 400.0] 3)", shouldEvalTo: .FloatLiteral(400.0))
  }

  /// A vector in function position with a negative index should produce an error.
  func testNegativeIndex() {
    expectThat("([100 200 300 400.0] -1)", shouldFailAs: .OutOfBoundsError)
  }

  /// A vector in function position with an out-of-bounds positive index should produce an error.
  func testTooLargeIndex() {
    expectThat("([100 200 300 400.0] 100)", shouldFailAs: .OutOfBoundsError)
  }

  /// A vector in function position should take exactly one argument.
  func testArity() {
    expectArityErrorFrom("([100 200 300 400.0] 0 nil)")
    expectArityErrorFrom("([100 200 300 400.0])")
  }

  /// A vector bound to a symbol should evaluate properly.
  func testWithSymbol() {
    runCode("(def testVec [1 4 9 16 25])")
    expectThat("(testVec 2)", shouldEvalTo: .IntegerLiteral(9))
  }

  /// When a vector is in function position, all expressions in the list should be evaluated.
  func testSideEffects() {
    expectThat("([(.print \"token1\") (.print \"value2\") 100] (do (.print \"marker3\") 2))",
      shouldEvalTo: .IntegerLiteral(100))
    expectOutputBuffer(toBe: "token1value2marker3")
  }
}

/// Test the use of maps in function position.
class TestFnPositionMaps : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A map in function position should return values for valid keys.
  func testValidKey() {
    expectThat("({:a 1 :b 2 :c 3} :a)", shouldEvalTo: .IntegerLiteral(1))
    expectThat("({:a 1 :b 2 :c 3} :b)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("({:a 1 :b 2 :c 3} :c)", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A map in function position should return values for valid keys, ignoring the fallback argument.
  func testValidKeyWithFallback() {
    expectThat("({:a 1 :b 2 :c 3} :a 501)", shouldEvalTo: .IntegerLiteral(1))
    expectThat("({:a 1 :b 2 :c 3} :b 230)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("({:a 1 :b 2 :c 3} :c 101)", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A map in function position should return nil for invalid keys if no fallback argument was provided.
  func testInvalidKey() {
    expectThat("({:a 1 :b 2 :c 3} :d)", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} nil)", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} \"foobar\")", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} 'a)", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} 'b)", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} 'c)", shouldEvalTo: .NilLiteral)
  }

  /// A map in function position should return the fallback argument for invalid keys if one exists.
  func testInvalidKeyWithFallback() {
    expectThat("({:a 1 :b 2 :c 3} 'a \"foobar\")", shouldEvalTo: .StringLiteral("foobar"))
    expectThat("({:a 1 :b 2 :c 3} 'b nil)", shouldEvalTo: .NilLiteral)
    expectThat("({:a 1 :b 2 :c 3} 'c [99])", shouldEvalTo: vectorWithItems(ConsValue.IntegerLiteral(99)))
  }

  /// When a map is in function position, all expressions in the list should be evaluated.
  func testSideEffects1() {
    expectThat("({(do (.print \"token1\") 9) (do (.print \"token2\") 9)} (do (.print \"token3\") 1) (do (.print \"token4\") 100))",
      shouldEvalTo: .IntegerLiteral(100))
    expectOutputBuffer(toBe: "token1token2token3token4")
  }

  /// When a map is in function position, all expressions in the list should be evaluated.
  func testSideEffects2() {
    expectThat("({(do (.print \"token1\") 1) (do (.print \"token2\") 9)} (do (.print \"token3\") 1) (do (.print \"token4\") 100))",
      shouldEvalTo: .IntegerLiteral(9))
    expectOutputBuffer(toBe: "token1token2token3token4")
  }

  /// A map in function position must be called with either 1 or 2 arguments.
  func testArity() {
    expectArityErrorFrom("({1 2 3 4})")
    expectArityErrorFrom("({1 2 3 4} 1 nil 2)")
  }
}

/// Test the use of symbols in function position.
class TestFnPositionSymbols : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A symbol in function position should return values for valid keys.
  func testValidKey() {
    expectThat("('a {'a 1 'b 2 'c 3})", shouldEvalTo: .IntegerLiteral(1))
    expectThat("('b {'a 1 'b 2 'c 3})", shouldEvalTo: .IntegerLiteral(2))
    expectThat("('c {'a 1 'b 2 'c 3})", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A symbol in function position should return values for valid keys, ignoring the fallback argument.
  func testValidKeyWithFallback() {
    expectThat("('a {'a 1 'b 2 'c 3} 501)", shouldEvalTo: .IntegerLiteral(1))
    expectThat("('b {'a 1 'b 2 'c 3} 230)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("('c {'a 1 'b 2 'c 3} 101)", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A symbol in function position should return nil for invalid keys if no fallback argument was provided.
  func testInvalidKey() {
    expectThat("('d {'a 1 'b 2 'c 3})", shouldEvalTo: .NilLiteral)
    expectThat("('c {:a 1 :b 2 :c 3})", shouldEvalTo: .NilLiteral)
    expectThat("('foo {\"foo\" 1 'b 2 'c 3})", shouldEvalTo: .NilLiteral)
  }

  /// A symbol in function position should return the fallback argument for invalid keys if one exists.
  func testInvalidKeyWithFallback() {
    expectThat("('d {'a 1 'b 2 'c 3} \"foobar\")", shouldEvalTo: .StringLiteral("foobar"))
    expectThat("('c {:a 1 :b 2 :c 3} nil)", shouldEvalTo: .NilLiteral)
    expectThat("('foo {\"foo\" 1 'b 2 'c 3} [99])", shouldEvalTo: vectorWithItems(ConsValue.IntegerLiteral(99)))
  }

  /// When a symbol is in function position, all expressions in the list should be evaluated.
  func testSideEffects() {
    expectThat("((do (.print \"token1\") 'a) {(do (.print \"token2\") 'a) (do (.print \"token3\") 9)} (do (.print \"token4\") 152))",
      shouldEvalTo: .IntegerLiteral(9))
    expectOutputBuffer(toBe: "token1token2token3token4")
  }

  /// A symbol in function position with a first parameter of unsupported type should return nil.
  func testWithUnsupported() {
    expectThat("('foo nil)", shouldEvalTo: .NilLiteral)
    expectThat("('foo true)", shouldEvalTo: .NilLiteral)
    expectThat("('foo false)", shouldEvalTo: .NilLiteral)
    expectThat("('foo 159)", shouldEvalTo: .NilLiteral)
    expectThat("('foo -2.9981)", shouldEvalTo: .NilLiteral)
    expectThat("('foo :a)", shouldEvalTo: .NilLiteral)
    expectThat("('foo 'a)", shouldEvalTo: .NilLiteral)
    expectThat("('foo \\a)", shouldEvalTo: .NilLiteral)
    expectThat("('foo \"foobar\")", shouldEvalTo: .NilLiteral)
    expectThat("('foo '('foo 'bar))", shouldEvalTo: .NilLiteral)
    expectThat("('foo ['foo 'bar])", shouldEvalTo: .NilLiteral)
    expectThat("('foo .+)", shouldEvalTo: .NilLiteral)
  }

  /// A symbol in function position with a first parameter of unsupported type should return the fallback.
  func testWithUnsupportedFallback() {
    expectThat("('foo nil 150)", shouldEvalTo: .IntegerLiteral(150))
    expectThat("('foo true 88)", shouldEvalTo: .IntegerLiteral(88))
    expectThat("('foo false 512)", shouldEvalTo: .IntegerLiteral(512))
    expectThat("('foo 159 89)", shouldEvalTo: .IntegerLiteral(89))
    expectThat("('foo -2.9981 10001)", shouldEvalTo: .IntegerLiteral(10001))
    expectThat("('foo :a -57)", shouldEvalTo: .IntegerLiteral(-57))
    expectThat("('foo 'a 2)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("('foo \\a 3)", shouldEvalTo: .IntegerLiteral(3))
    expectThat("('foo \"foobar\" 834)", shouldEvalTo: .IntegerLiteral(834))
    expectThat("('foo '('foo 'bar) 141)", shouldEvalTo: .IntegerLiteral(141))
    expectThat("('foo ['foo 'bar] 600000)", shouldEvalTo: .IntegerLiteral(600000))
    expectThat("('foo .+ 15)", shouldEvalTo: .IntegerLiteral(15))
  }

  /// A symbol in function position must be called with either 1 or 2 arguments.
  func testArity() {
    expectArityErrorFrom("('a)")
    expectArityErrorFrom("('a {'a 1 'b 2} 1 nil)")
  }
}

/// Test the use of keywords in function position.
class TestFnPositionKeywords : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A keyword in function position should return values for valid keys.
  func testValidKey() {
    expectThat("(:a {:a 1 :b 2 :c 3})", shouldEvalTo: .IntegerLiteral(1))
    expectThat("(:b {:a 1 :b 2 :c 3})", shouldEvalTo: .IntegerLiteral(2))
    expectThat("(:c {:a 1 :b 2 :c 3})", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A keyword in function position should return values for valid keys, ignoring the fallback argument.
  func testValidKeyWithFallback() {
    expectThat("(:a {:a 1 :b 2 :c 3} 501)", shouldEvalTo: .IntegerLiteral(1))
    expectThat("(:b {:a 1 :b 2 :c 3} 230)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("(:c {:a 1 :b 2 :c 3} 101)", shouldEvalTo: .IntegerLiteral(3))
  }

  /// A keyword in function position should return nil for invalid keys if no fallback argument was provided.
  func testInvalidKey() {
    expectThat("(:d {:a 1 :b 2 :c 3})", shouldEvalTo: .NilLiteral)
    expectThat("(:c {'a 1 'b 2 'c 3})", shouldEvalTo: .NilLiteral)
    expectThat("(:foo {\"foo\" 1 :b 2 :c 3})", shouldEvalTo: .NilLiteral)
  }

  /// A keyword in function position should return the fallback argument for invalid keys if one exists.
  func testInvalidKeyWithFallback() {
    expectThat("(:d {:a 1 :b 2 :c 3} \"foobar\")", shouldEvalTo: .StringLiteral("foobar"))
    expectThat("(:c {'a 1 'b 2 'c 3} nil)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo {\"foo\" 1 :b 2 :c 3} [99])", shouldEvalTo: vectorWithItems(ConsValue.IntegerLiteral(99)))
  }

  /// When a keyword is in function position, all expressions in the list should be evaluated.
  func testSideEffects() {
    expectThat("((do (.print \"token1\") :a) {(do (.print \"token2\") :a) (do (.print \"token3\") 9)} (do (.print \"token4\") 152))",
      shouldEvalTo: .IntegerLiteral(9))
    expectOutputBuffer(toBe: "token1token2token3token4")
  }

  /// A keyword in function position with a first parameter of unsupported type should return nil.
  func testWithUnsupported() {
    expectThat("(:foo nil)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo true)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo false)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo 159)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo -2.9981)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo :a)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo 'a)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo \\a)", shouldEvalTo: .NilLiteral)
    expectThat("(:foo \"foobar\")", shouldEvalTo: .NilLiteral)
    expectThat("(:foo '(:foo :bar))", shouldEvalTo: .NilLiteral)
    expectThat("(:foo [:foo :bar])", shouldEvalTo: .NilLiteral)
    expectThat("(:foo .+)", shouldEvalTo: .NilLiteral)
  }

  /// A keyword in function position with a first parameter of unsupported type should return the fallback.
  func testWithUnsupportedFallback() {
    expectThat("(:foo nil 150)", shouldEvalTo: .IntegerLiteral(150))
    expectThat("(:foo true 88)", shouldEvalTo: .IntegerLiteral(88))
    expectThat("(:foo false 512)", shouldEvalTo: .IntegerLiteral(512))
    expectThat("(:foo 159 89)", shouldEvalTo: .IntegerLiteral(89))
    expectThat("(:foo -2.9981 10001)", shouldEvalTo: .IntegerLiteral(10001))
    expectThat("(:foo :a -57)", shouldEvalTo: .IntegerLiteral(-57))
    expectThat("(:foo 'a 2)", shouldEvalTo: .IntegerLiteral(2))
    expectThat("(:foo \\a 3)", shouldEvalTo: .IntegerLiteral(3))
    expectThat("(:foo \"foobar\" 834)", shouldEvalTo: .IntegerLiteral(834))
    expectThat("(:foo '(:foo :bar) 141)", shouldEvalTo: .IntegerLiteral(141))
    expectThat("(:foo [:foo :bar] 600000)", shouldEvalTo: .IntegerLiteral(600000))
    expectThat("(:foo .+ 15)", shouldEvalTo: .IntegerLiteral(15))
  }

  /// A keyword in function position must be called with either 1 or 2 arguments.
  func testArity() {
    expectArityErrorFrom("(:a)")
    expectArityErrorFrom("(:a {:a 1 :b 2} 1 nil)")
  }
}

/// Test the use of invalid types in function position.
class TestFnPositionInvalidTypes : InterpreterTest {

  /// nil should cause an error if used in function position.
  func testNilInFnPosition() {
    expectThat("(nil)", shouldFailAs: .NotEvalableError)
  }

  /// Bools should cause an error if used in function position.
  func testBoolInFnPosition() {
    expectThat("(true)", shouldFailAs: .NotEvalableError)
    expectThat("(false)", shouldFailAs: .NotEvalableError)
  }

  /// Characters should cause an error if used in function position.
  func testCharacterInFnPosition() {
    expectThat("(\\a 0)", shouldFailAs: .NotEvalableError)
  }

  /// Strings should cause an error if used in function position.
  func testStringInFnPosition() {
    expectThat("(\"the quick brown fox\" 0)", shouldFailAs: .NotEvalableError)
  }

  /// Lists should cause an error if used in function position.
  func testListInFnPosition() {
    expectThat("('(100 200 300 400.0) 0)", shouldFailAs: .NotEvalableError)
  }

  /// Integers should cause an error if used in function position.
  func testIntInFnPosition() {
    expectThat("(1009)", shouldFailAs: .NotEvalableError)
  }

  /// Floating-point numbers should cause an error if used in function position.
  func testFloatInFnPosition() {
    expectThat("(100.0009)", shouldFailAs: .NotEvalableError)
  }
}
