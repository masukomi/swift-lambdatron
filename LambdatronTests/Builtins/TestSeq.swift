//
//  TestSeq.swift
//  Lambdatron
//
//  Created by Austin Zheng on 2/3/15.
//  Copyright (c) 2015 Austin Zheng. All rights reserved.
//

import Foundation

class TestSeqBuiltin : InterpreterTest {

  /// .seq should return nil if passed in nil.
  func testWithNil() {
    expectThat("(.seq nil)", shouldEvalTo: .Nil)
  }

  /// .seq should return nil for empty collections.
  func testWithEmptyCollections() {
    expectThat("(.seq \"\")", shouldEvalTo: .Nil)
    expectThat("(.seq ())", shouldEvalTo: .Nil)
    expectThat("(.seq [])", shouldEvalTo: .Nil)
    expectThat("(.seq {})", shouldEvalTo: .Nil)
  }

  /// .seq should return a sequence comprised of the characters of a string.
  func testWithStrings() {
    expectThat("(.seq \"abc\")",
      shouldEvalTo: listWithItems(.CharAtom("a"), .CharAtom("b"), .CharAtom("c")))
    expectThat("(.seq \"\\n\\\\\nq\")",
      shouldEvalTo: listWithItems(.CharAtom("\n"), .CharAtom("\\"), .CharAtom("\n"),
        .CharAtom("q")))
    expectThat("(.seq \"foobar\")",
      shouldEvalTo: listWithItems(.CharAtom("f"), .CharAtom("o"), .CharAtom("o"),
        .CharAtom("b"), .CharAtom("a"), .CharAtom("r")))
  }

  /// .seq should return a sequence comprised of the elements in a list.
  func testWithLists() {
    expectThat("(.seq '(true false nil 1 2.1 3))", shouldEvalTo: listWithItems(true, false, .Nil, 1, 2.1, 3))
    expectThat("(.seq '((1 2) (3 4) (5 6) (7 8) ()))", shouldEvalTo:
      listWithItems(listWithItems(1, 2), listWithItems(3, 4), listWithItems(5, 6), listWithItems(7, 8),
        listWithItems()))
  }

  /// .seq should return a sequence comprised of the elements in a vector.
  func testWithVectors() {
    expectThat("(.seq [false true nil 1 2.1 3])", shouldEvalTo: listWithItems(false, true, .Nil, 1, 2.1, 3))
    expectThat("(.seq [[1 2] [3 4] [5 6] [7 8] []])", shouldEvalTo:
      listWithItems(vectorWithItems(1, 2), vectorWithItems(3, 4), vectorWithItems(5, 6), vectorWithItems(7, 8),
        vectorWithItems()))
  }

  /// .seq should return a sequence comprised of the key-value pairs in a map.
  func testWithMaps() {
    let a = interpreter.context.keywordForName("a")
    let b = interpreter.context.keywordForName("b")
    let c = interpreter.context.keywordForName("c")
    expectThat("(.seq {:a 1 :b 2 :c 3 \\d 4})", shouldEvalTo:
      listWithItems(vectorWithItems(.Keyword(b), 2), vectorWithItems(.Keyword(c), 3), vectorWithItems(.Keyword(a), 1),
        vectorWithItems(.CharAtom("d"), 4)))
    expectThat("(.seq {\"foo\" \\a nil \"baz\" true \"bar\"})", shouldEvalTo: listWithItems(
      vectorWithItems(.Nil, .StringAtom("baz")),
      vectorWithItems(true, .StringAtom("bar")),
      vectorWithItems(.StringAtom("foo"), .CharAtom("a"))))
  }

  /// .seq should reject non-collection arguments.
  func testWithInvalidTypes() {
    expectThat("(.seq true)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq false)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq 152)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq 3.141592)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq :foo)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq 'foo)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq \\f)", shouldFailAs: .InvalidArgumentError)
    expectThat("(.seq .+)", shouldFailAs: .InvalidArgumentError)
  }

  /// .seq should only take one argument.
  func testArity() {
    expectArityErrorFrom("(.seq)")
    expectArityErrorFrom("(.seq nil nil)")
  }
}
