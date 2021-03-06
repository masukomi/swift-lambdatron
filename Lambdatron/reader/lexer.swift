//
//  lexer.swift
//  Lambdatron
//
//  Created by Austin Zheng on 11/12/14.
//  Copyright (c) 2014 Austin Zheng. All rights reserved.
//

import Foundation

enum LexResult {
  case Success([LexToken])
  case Failure(ReadError)
}

/// Tokens representing special syntax characters.
enum SyntaxToken {
  case LeftParentheses            // left parentheses '('
  case RightParentheses           // right parentheses ')'
  case LeftSquareBracket          // left square bracket '['
  case RightSquareBracket         // right square bracket ']'
  case LeftBrace                  // left brace '{'
  case RightBrace                 // right brace '}'
  case Quote                      // single quote '''
  case Backquote                  // isolate grave accent '`'
  case Tilde                      // tilde '~'
  case TildeAt                    // tilde followed by at '~@'
  case HashLeftBrace              // hash-left brace '#{'
  case HashQuote                  // hash-quote '#''
  case HashLeftParentheses        // hash-left parentheses '#('
  case HashUnderscore             // hash-underscore '#_'
}

/// Tokens that come out of the lex() function, intended as input to the parser.
enum LexToken {
  case Syntax(SyntaxToken)
  case Nil                        // nil
  case CharLiteral(Character)     // character literal
  case StringLiteral(String)      // string (denoted by double quotes)
  case RegexPattern(String)       // a pattern for a regular expression, denoted by #"SomeRegexPattern"
  case Integer(Int)               // integer number
  case FlPtNumber(Double)         // floating-point number
  case Boolean(Bool)              // boolean (true or false)
  case Keyword(String)            // keyword (prefixed by ':')
  case Identifier(String)         // unknown identifier (function or variable name)
  case Special(SpecialForm)       // a special form (e.g. 'quote')
  case BuiltInFunction(BuiltIn)   // a built-in function

  /// Return whether or not this LexToken is a specific syntax token.
  func isA(token: SyntaxToken) -> Bool {
    switch self {
    case let .Syntax(s): return s == token
    default: return false
    }
  }
}

/// Lexer represents a collection of functions and static objects used to lex input strings into tokens. It is not
/// intended to be instantiated.
private struct Lexer {
  enum RawLexToken {
    case Syntax(SyntaxToken)
    case CharLiteral(Character)
    case StringLiteral(String)
    case RegexPattern(String)
    case Unknown(String)
  }

  enum StringLexResult {
    case Success(String), Failure(ReadError)
  }

  enum CharacterLexResult {
    case Success(Character), Failure(ReadError)
  }

  enum RawLexTokenLexResult {
    case Success(RawLexToken), Failure(ReadError)
  }

  enum RawLexTokenArrayLexResult {
    case Success([RawLexToken]), Failure(ReadError)
  }

  // Character sets
  static let whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet()
  static let likeWhitespace = NSCharacterSet(charactersInString: ",")
  static let canFollowCharacter = NSCharacterSet(charactersInString: "\\()[]{}\"`@~")

  static let formatter = NSNumberFormatter()

  /// Return whether or not the character is considered whitespace (and can be discarded) by the lexer.
  static func isWhitespace(char: Character) -> Bool {
    return characterIsMemberOfSet(char, whitespace) || characterIsMemberOfSet(char, likeWhitespace)
  }

  /// Perform the first phase of lexing. This takes in a string representing source code, and returns an array of
  /// RawLexTokens.
  static func lex1(string: String) -> RawLexTokenArrayLexResult {
    /// A list of tokens generated by the lex1 function.
    var rawTokenBuffer : [RawLexToken] = []
    /// The current position within the input string.
    var index = string.startIndex
    // currentToken can only contain either a StringAtom or an Unknown token
    var currentToken : String = ""

    /// Helper function - flush the current-in-progress token to the token buffer and reset the in-progress token.
    func flushTokenToBuffer() {
      if !currentToken.isEmpty {
        rawTokenBuffer.append(.Unknown(currentToken))
      }
      currentToken = ""
    }

    /// Helper function - flush the token, append a new one, and advance the index by one.
    func appendSyntaxToken(token: SyntaxToken) {
      if !currentToken.isEmpty {
        rawTokenBuffer.append(.Unknown(currentToken))
      }
      currentToken = ""
      rawTokenBuffer.append(.Syntax(token))
      index = index.successor()
    }

    while index < string.endIndex {
      let char = string[index]

      switch char {
      case ";":
        flushTokenToBuffer()                          // User starting a comment with a ;
        // Consume a comment
        consumeComment(string, index: &index)
      case "\"":
        flushTokenToBuffer()                          // User starting a string with an opening "
        // Consume the string starting at the current position.
        switch consumeString(string, index: &index, raw: false) {
        case let .Success(string): rawTokenBuffer.append(.StringLiteral(string))
        case let .Failure(error): return .Failure(error)
        }
      case "(":
        appendSyntaxToken(.LeftParentheses)
      case ")":
        appendSyntaxToken(.RightParentheses)
      case "[":
        appendSyntaxToken(.LeftSquareBracket)
      case "]":
        appendSyntaxToken(.RightSquareBracket)
      case "{":
        appendSyntaxToken(.LeftBrace)
      case "}":
        appendSyntaxToken(.RightBrace)
      case "'":
        appendSyntaxToken(.Quote)
      case "`":
        appendSyntaxToken(.Backquote)
      case "~":
        flushTokenToBuffer()                          // Tilde can either signify ~ or ~@
        let token = consumeTilde(string, index: &index)
        rawTokenBuffer.append(.Syntax(token))
      case "\\":
        flushTokenToBuffer()                          // Backslash represents a character literal
        switch consumeCharacter(string, index: &index) {
        case let .Success(character): rawTokenBuffer.append(.CharLiteral(character))
        case let .Failure(error): return .Failure(error)
        }
      case "#":
        flushTokenToBuffer()                          // Hash represents some sort of dispatch macro (#(, #', #"", etc)
        switch consumeHash(string, index: &index) {
        case let .Success(token): rawTokenBuffer.append(token)
        case let .Failure(error): return .Failure(error)
        }
      case _ where isWhitespace(char):
        flushTokenToBuffer()                          // Whitespace/newline or equivalent (e.g. commas)
        index = index.successor()
      default:
        currentToken.append(char)                     // Any other valid character
        index = index.successor()
      }
    }

    // If there's one last token left, flush it
    flushTokenToBuffer()
    // Return the buffer
    return .Success(rawTokenBuffer)
  }

  /// Perform the second phase of lexing, taking RawLexTokens and turning them into LexTokens. This may involve taking
  /// Unknown tokens and figuring out if they correspond to literals or other privileged forms.
  static func lex2(rawTokenBuffer: [RawLexToken]) -> LexResult {
    var tokenBuffer : [LexToken] = []
    for rawToken in rawTokenBuffer {
      switch rawToken {
      case let .Syntax(s): tokenBuffer.append(.Syntax(s))
      case let .CharLiteral(c): tokenBuffer.append(.CharLiteral(c))
      case let .StringLiteral(s): tokenBuffer.append(.StringLiteral(s))
      case let .RegexPattern(s): tokenBuffer.append(.RegexPattern(s))
      case let .Unknown(unknown):
        // Figure out what to do with the token
        if let specialForm = SpecialForm(rawValue: unknown) {
          // Special form
          tokenBuffer.append(.Special(specialForm))
        }
        else if let builtIn = BuiltIn(rawValue: unknown) {
          // Built-in function
          tokenBuffer.append(.BuiltInFunction(builtIn))
        }
        else if unknown == ":" {
          // This is an invalid keyword (no body).
          return .Failure(ReadError(.InvalidKeywordError))
        }
        else if unknown[unknown.startIndex] == ":" {
          // This is a keyword (starts with ":" and has at least one other character)
          tokenBuffer.append(.Keyword(unknown[unknown.startIndex.successor()..<unknown.endIndex]))
        }
        else if unknown == "nil" {
          // Literal nil
          tokenBuffer.append(.Nil)
        }
        else if unknown == "false" {
          // Literal bool
          tokenBuffer.append(.Boolean(false))
        }
        else if unknown == "true" {
          // Literal bool
          tokenBuffer.append(.Boolean(true))
        }
        else if let numberToken = numberFromString(unknown) {
          // Literal number
          tokenBuffer.append(numberToken)
        }
        else {
          // Identifier
          tokenBuffer.append(.Identifier(unknown))
        }
      }
    }
    return .Success(tokenBuffer)
  }

  /// Given a string representing an entire buffer, as well as an index representing a position in the buffer
  /// corresponding to the start of a comment, advance the index to the point after the comment ends.
  static func consumeComment(str: String, inout index: String.Index) {
    var current = index

    while current < str.endIndex {
      let character = str[current]
      current = current.successor()
      if characterIsMemberOfSet(character, NSCharacterSet.newlineCharacterSet()) {
        // Character is a newline
        break
      }
    }
    // Found the newline, or reached the end of the entire buffer
    index = current
  }

  /// Given a string representing an entire buffer, as well as an index representing a position in the buffer
  /// corresponding to the start of a string literal, try to parse out the string. This function returns a string or nil
  /// if unsuccessful. Only if successful, it will also update the index position.
  static func consumeString(str: String, inout index: String.Index, raw: Bool) -> StringLexResult {
    // Precondition: str[index] must be the double quote denoting the beginning of the string to consume.

    var current = index
    // Advance position to the first character in the string proper.
    current = current.successor()
    let start = current
    var buffer = ""

    while current < str.endIndex {
      let character = str[current]
      switch character {
      case "\"":
        // Reached the end of the string literal. Return it and update 'index'.
        index = current.successor()
        return .Success(buffer)
      case "\\":
        if raw {
          // No special privileges for escape characters...
          fallthrough
        }
        // Found a control character. Consume the character following it.
        if current == str.endIndex.predecessor() {
          // An escape character cannot be the last character in the input
          return .Failure(ReadError(.InvalidStringEscapeSequenceError))
        }
        if let escape = escapeFor(str[current.successor()]) {
          // Append the escape character and skip two characters.
          buffer.append(escape)
          current = current.successor().successor()
        }
        else {
          // The escape sequence was not valid.
          return .Failure(ReadError(.InvalidStringEscapeSequenceError))
        }
      default:
        // Any other token is just skipped.
        buffer.append(character)
        current = current.successor()
      }
    }
    // If we've gotten here we've reached the end of str, but without terminating our string literal.
    return .Failure(ReadError(.NonTerminatedStringError))
  }

  /// Given a string and a start index, determine whether the token at the start index is '~' or '~@', returning a
  /// syntax token or error and updating the index appropriately.
  static func consumeTilde(str: String, inout index: String.Index) -> SyntaxToken {
    // Precondition: str[index] must be '~'.
    if index == str.endIndex.predecessor() {
      // The '~' is at the end of the string.
      index = index.successor()
      return .Tilde
    }
    // We need to examine the following character.
    let next = str[index.successor()]
    if next == "@" {
      index = index.successor().successor()
      return .TildeAt
    }
    else {
      index = index.successor()
      return .Tilde
    }
  }

  /// Given a string and a start index which points to a '#' in the string, determine the proper dispatch macro the '#'
  /// corresponds to and build it, updating the index appropriately.
  static func consumeHash(str: String, inout index: String.Index) -> RawLexTokenLexResult {
    // Precondition: str[index] must be '#'.
    if index == str.endIndex.predecessor() {
      // The '#' is at the end of the string (this is invalid)
      return .Failure(ReadError(.InvalidDispatchMacroError))
    }
    // Examine the character that comes after the '#'
    let this = str[index.successor()]
    switch this {
    case "{":           // Set start marker
      index = index.successor().successor()
      return .Success(.Syntax(.HashLeftBrace))
    case "\"":          // Regex pattern
      index = index.successor()
      let result = consumeString(str, index: &index, raw: true)
      switch result {
      case let .Success(s): return .Success(.RegexPattern(s))
      case let .Failure(f): return .Failure(f)
      }
    case "'":           // Var-quote
      index = index.successor().successor()
      return .Success(.Syntax(.HashQuote))
    case "(":           // Inline function start
      index = index.successor().successor()
      return .Success(.Syntax(.HashLeftParentheses))
    case "_":           // Ignore next form
      index = index.successor().successor()
      return .Success(.Syntax(.HashUnderscore))
    default:
      return .Failure(ReadError(.InvalidDispatchMacroError))
    }
  }

  /// Given a string and a start index, return the character described by the character literal at that position, or
  /// nil, and update the index appropriately.
  static func consumeCharacter(str: String, inout index: String.Index) -> CharacterLexResult {
    // Precondition: str[index] is the "\" character that begins the character literal.
    if index == str.endIndex.predecessor() {
      // No character literals can start at the very end of the string.
      return .Failure(ReadError(.InvalidCharacterError))
    }

    let start = index.successor()
    // The first character in the character literal
    var firstCharacter = str[start]
    // The index of the character following the first character in the character literal expression
    let followingIndex = start.successor()

    if followingIndex == str.endIndex || characterTerminatesLiteral(str[followingIndex]) {
      // Single-character literal
      index = followingIndex
      return .Success(firstCharacter)
    }
    if firstCharacter == "u"  {
      // Possible unicode character literal
      var thisIndex = start.successor()
      if let d0 = digitAsNumber(str, &thisIndex, .Hexadecimal) {
        if let d1 = digitAsNumber(str, &thisIndex, .Hexadecimal) {
          if let d2 = digitAsNumber(str, &thisIndex, .Hexadecimal) {
            if let d3 = digitAsNumber(str, &thisIndex, .Hexadecimal) {
              if thisIndex == str.endIndex || characterTerminatesLiteral(str[thisIndex]) {
                index = thisIndex
                let value : Int = 4096*d0 + 256*d1 + 16*d2 + d3
                return .Success(Character(UnicodeScalar(value)))
              }
            }
          }
        }
      }
      // Note that there are no named characters whose names begin with 'u', so this is acceptable.
      return .Failure(ReadError(.InvalidUnicodeError))
    }
    if firstCharacter == "o" {
      // Possible octal character literal
      var thisIndex = start.successor()
      if let d0 = digitAsNumber(str, &thisIndex, .Octal) {
        if let d1 = digitAsNumber(str, &thisIndex, .Octal) {
          if let d2 = digitAsNumber(str, &thisIndex, .Octal) {
            if thisIndex == str.endIndex || characterTerminatesLiteral(str[thisIndex]) {
              index = thisIndex
              let value : Int = 64*d0 + 8*d1 + d2
              if value < 256 { return .Success(Character(UnicodeScalar(value))) }
            }
          }
        }
      }
      // Note that there are no named characters whose names begin with 'o', so this is acceptable.
      return .Failure(ReadError(.InvalidOctalError))
    }

    // At this point, the character is either a named character or invalid.
    // Find the end of the character.
    var current = followingIndex
    while current < str.endIndex {
      current = current.successor()
      if current == str.endIndex || characterTerminatesLiteral(str[current]) {
        break
      }
    }
    // Switch on the name of the character.
    index = current
    switch str[start..<current] {
    case "space": return .Success(" ")
    case "tab": return .Success("\t")
    case "newline": return .Success("\n")
    case "return": return .Success("\r")
    case "backspace": return .Success(Character(UnicodeScalar(8)))
    case "formfeed": return .Success(Character(UnicodeScalar(12)))
    default:
      // Reset index
      index = start.predecessor()
      return .Failure(ReadError(.InvalidCharacterError))
    }
  }

  /// Return whether or not a character immediately following a character literal can mark the beginning of the next
  /// token to be lexed.
  static func characterTerminatesLiteral(c: Character) -> Bool {
    // A character can be adjacent to:
    // * Another character (e.g. \a\a)
    // * The start or end of a list (e.g. (\a))
    // * The start or end of a vector (e.g. \a[])
    // * The start or end of a bracketed form (e.g. \a{})
    // * The start of a string (e.g. \a"hello")
    // * The macro symbols `, @, or ~
    // A character cannot touch a keyword (:), literal quote ('), hash (#), number, true, false, or nil.
    return characterIsMemberOfSet(c, whitespace) || characterIsMemberOfSet(c, canFollowCharacter)
  }

  /// Return a LexToken representing a number type if the input string can be converted into a number, or nil otherwise.
  static func numberFromString(str: String) -> LexToken? {
    enum NumberMode { case Integer, FloatingPoint }
    var mode : NumberMode = .Integer

    // Scan string for "."
    for item in str {
      if item == "." {
        switch mode {
        case .Integer:
          mode = .FloatingPoint
        case .FloatingPoint:
          // A second decimal point makes the number invalid
          return nil
        }
      }
    }

    // The classic 'isNumber()' function.
    formatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
    if let number = formatter.numberFromString(str) {
      switch mode {
      case .Integer:
        return LexToken.Integer(number.longValue)
      case .FloatingPoint:
        return LexToken.FlPtNumber(number.doubleValue)
      }
    }
    return nil
  }
}

/// Given a raw input (as a string), lex it into individual tokens.
func lex(raw: String) -> LexResult {
  let result = Lexer.lex1(raw)
  switch result {
  case let .Success(rawTokenBuffer):
    return Lexer.lex2(rawTokenBuffer)
  case let .Failure(f): return .Failure(f)
  }
}

/// Given the second character in a two-character escape sequence (e.g. "n" in "\n"), return the character the escape
/// sequence corresponds to (if one exists).
private func escapeFor(sequence: Character) -> Character? {
  switch sequence {
  case "r": return "\r"
  case "n": return "\n"
  case "t": return "\t"
  case "\"": return "\""
  case "\\": return "\\"
  default: return nil
  }
}

private enum NumberType { case Decimal, Octal, Hexadecimal }

/// Given a string, an index within the string, and a type of number, return the numeric value of the character at the
/// index, or nil if the index is invalid or the character is not a valid digit for the number type. This function
/// will advance the index as long as the index isn't past the end of the string.
private func digitAsNumber(string: String, inout idx: String.Index, type: NumberType) -> Int? {
  if idx >= string.endIndex { return nil }
  var value : Int? = nil
  switch string[idx] {
  case "0": value = 0
  case "1": value = 1
  case "2": value = 2
  case "3": value = 3
  case "4": value = 4
  case "5": value = 5
  case "6": value = 6
  case "7": value = 7
  case "8" where type == .Decimal || type == .Hexadecimal: value = 8
  case "9" where type == .Decimal || type == .Hexadecimal: value = 9
  case "a", "A" where type == .Hexadecimal: value = 10
  case "b", "B" where type == .Hexadecimal: value = 11
  case "c", "C" where type == .Hexadecimal: value = 12
  case "d", "D" where type == .Hexadecimal: value = 13
  case "e", "E" where type == .Hexadecimal: value = 14
  case "f", "F" where type == .Hexadecimal: value = 15
  default: break
  }
  idx = idx.successor()
  return value
}
