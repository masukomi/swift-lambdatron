//
//  operators.swift
//  Lambdatron
//
//  Created by Austin Zheng on 11/19/14.
//  Copyright (c) 2014 Austin Zheng. All rights reserved.
//

import Foundation

public func ==(lhs: ReaderMacro, rhs: ReaderMacro) -> Bool {
  return lhs.type == rhs.type && lhs.form == rhs.form
}

public func ==<T>(lhs: ListType<T>, rhs: ListType<T>) -> Bool {
  if lhs.isEmpty && rhs.isEmpty {
    return true
  }
  else if lhs.isEmpty || rhs.isEmpty {
    // One list is not empty
    return false
  }
  // Walk through the lists
  var leftGenerator = lhs.generate()
  var rightGenerator = rhs.generate()
  while true {
    let left = leftGenerator.next()
    let right = rightGenerator.next()
    if left == nil && right == nil {
      // Reached the end of both lists
      return true
    }
    if let left = left {
      if let right = right {
        if left != right {
          return false
        }
        continue
      }
    }
    // One is nil, the other isn't
    return false
  }
}

func ==(lhs: ListType<ConsValue>, rhs: VectorType) -> Bool {
  if rhs.count == 0 {
    return lhs.isEmpty
  }
  var idx = 0
  for item in lhs {
    if idx == rhs.count || item != rhs[idx] {
      // No more items in the array, or unequal items
      return false
    }
    idx += 1
  }
  // There can't be any more elements in the array
  return idx == (rhs.count - 1)
}

public func ==(lhs: ConsValue, rhs: ConsValue) -> Bool {
  switch lhs {
  case let .Symbol(v1):
    switch rhs {
    case let .Symbol(v2): return v1 == v2  // Can happen if comparing two quoted symbols
    default: return false
    }
  case let .Keyword(k1):
    switch rhs {
    case let .Keyword(k2): return k1 == k2
    default: return false
    }
  case let .Special(s1):
    switch rhs {
    case let .Special(s2): return s1 == s2
    default: return false
    }
  case let .BuiltInFunction(b1):
    switch rhs {
    case let .BuiltInFunction(b2): return b1 == b2
    default: return false
    }
  case .Nil:
    switch rhs {
    case .Nil: return true
    default: return false
    }
  case let .BoolAtom(b1):
    switch rhs {
    case let .BoolAtom(b2): return b1 == b2
    default: return false
    }
  case let .IntAtom(i1):
    switch rhs {
    case let .IntAtom(i2): return i1 == i2
    default: return false
    }
  case let .FloatAtom(n1):
    switch rhs {
    case let .FloatAtom(n2): return n1 == n2
    default: return false
    }
  case let .CharAtom(c1):
    switch rhs {
    case let .CharAtom(c2): return c1 == c2
    default: return false
    }
  case let .StringAtom(s1):
    switch rhs {
    case let .StringAtom(s2): return s1 == s2
    default: return false
    }
  case let .Regex(r1):
    switch rhs {
    case let .Regex(r2): return r1.isEqual(r2)
    default: return false
    }
  case let .List(l1):
    switch rhs {
    case let .List(l2): return l1 == l2
    case let .Vector(v2): return l1 == v2
    default: return false
    }
  case let .Vector(v1):
    switch rhs {
    case let .List(l2): return l2 == v1
    case let .Vector(v2): return v1 == v2
    default: return false
    }
  case let .Map(m1):
    switch rhs {
    case let .Map(m2): return m1 == m2
    default: return false
    }
  case let .FunctionLiteral(f1):
    switch rhs {
    case let .FunctionLiteral(f2): return f1 === f2
    default: return false
    }
  case .ReaderMacroForm: return false
  }
}
