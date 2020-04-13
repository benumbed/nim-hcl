## 
## Lexer for HCL
## NOTE: This uses Unicode runes (for the future), but isn't really unicode compatible yet
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import strformat
import unicode as uc

import ./streamer

type HclSyntaxError* = object of system.CatchableError

type HclTokenTypes* = enum
    HIllegal,
    HEof,
    HComment,

    HIdent,
    HNumber,
    HFloat,
    HBool,
    HString,
    HHeredoc,
    
    # Operators
    HLBrack,
    HLBrace,
    HComma,
    HPeriod,
    HRBrack,
    HRBrace,
    HAssign,
    HAdd,
    HSub

type HclToken* = tuple[kind: HclTokenTypes, token: string]
type HclTokens* = seq[HclToken]
type SourceLocation* = object
    line*: int
    column*: int

const COMMENT_CHARS*: seq[Rune] = @[Rune('#'), Rune('/')]
const EOL_CHARS*: seq[Rune] = @[Rune('\n'), Rune('\r')]

proc injectLoc(msg: string, loc: SourceLocation): string = &("{msg} (Ln {loc.line} Col {loc.column})")
template newException(exceptn: typedesc, message: string, loc: SourceLocation, 
                     parentException: ref Exception = nil): untyped =
    ## Re-implements Nim's `newException` only with the ability to print the current HCL source location as part of
    ## the error message
    (ref exceptn)(msg: message.injectLoc(loc), parent: parentException)


proc isDigit*(c: Rune): bool =
    ## Unicode compatible numeric check
    (c <= '9') and (c >= '0')


proc readIdentifier(stream: var Streamer, loc: var SourceLocation): HclToken =
    ## Reads an identifier from the stream and returns a new token
    var token: string

    const altRunes = @[Rune('-'), Rune('.')]

    while true:
        let chr = stream.readRune()

        if chr.isAlpha or chr.isDigit or chr in altRunes:
            token.add(chr)
            continue
        
        break

    return (HIdent, token)

proc readNumber(stream: var Streamer, loc: var SourceLocation): HclToken =
    ## Reads a number from the stream
    var number: string

    # TODO: Numeric validation and type selection
    while true:
        let chr = stream.readRune()

        if not(chr.isDigit or chr == 'x' or chr == '.'):
            break
        
        number.add(chr)

    return (HNumber, number)


proc readComment(stream: var Streamer, loc: var SourceLocation): HclToken =
    ## Reads a comment from the stream
    var token: string
    # Note, we don't include the '#' in the token, because if we reproduce this, we'll add it during rendering

    while true:
        let chr = stream.readRune()
        if chr in EOL_CHARS or stream.atEnd:
            stream.incLineCount
            break
        
        token.add(chr)

    return (HComment, token)

proc readString(stream: var Streamer, loc: var SourceLocation): HclToken =
    ## Reads a quoted string from the stream
    var token: string
    
    # Remove the leading "
    stream.setPosition(stream.getPosition+1)
    while true:
        let chr = stream.readRune()
        if chr == '"':
            break
        
        token.add(chr)
    
    return (HString, token)


proc readHeredoc(stream: var Streamer, loc: var SourceLocation): HclToken =
    ## Reads a heredoc from the stream
    var heredoc: string
    var anchor: string

    const indentChar = '-'

    var chr = stream.readRune()
    if stream.readRune() != '<':
        raise newException(HclSyntaxError, fmt"Expected second '<' in heredoc, got {chr}", loc)

    # Read the anchor
    while true:
        chr = stream.readRune()
        if chr in EOL_CHARS:
            stream.incLineCount
            break
        anchor.add(chr)

    if anchor == "":
        raise newException(HclSyntaxError, "Heredoc missing anchor text", loc)

    while true:
        if stream.peekStr(anchor.len) == anchor:
            stream.incPosition(anchor.len)
            break
        
        if stream.atEnd():
            raise newException(HclSyntaxError, "Encountered unexpected EOF while processing heredoc, no terminating anchor", loc)

        # TODO: Allow for '-' in heredoc
        heredoc.add(stream.readRune())
    
    return (HHeredoc, heredoc)


proc lex*(stream: var Streamer): HclTokens =
    ## Analyzes `stream` and returns the tokens within
    var srcLoc = SourceLocation()
    srcLoc.line = 1

    while not stream.atEnd():
        var chr = stream.peekRune()

        if chr.isWhiteSpace:
            stream.incPosition

            if chr in EOL_CHARS:
                stream.incLineCount
            continue

        elif chr in COMMENT_CHARS:
            result.add(stream.readComment(srcLoc))
            continue

        elif chr == '"':
            result.add(stream.readString(srcLoc))
            continue

        elif chr.isAlpha:
            result.add(stream.readIdentifier(srcLoc))
            continue

        elif chr.isDigit:
            result.add(stream.readNumber(srcLoc))
            continue

        # Operators
        
        chr = stream.readRune()
        srcLoc.column.inc

        if chr == '<':
            result.add(stream.readHeredoc(srcLoc))
            continue

        elif chr == '{':
            result.add((HLBrace, chr.toUtf8))
            continue

        elif chr == '}':
            result.add((HRBrace, chr.toUtf8))
            continue

        elif chr == '[':
            result.add((HLBrack, chr.toUtf8))
            continue

        elif chr == ']':
            result.add((HRBrack, chr.toUtf8))
            continue

        elif chr == ',':
            result.add((HComma, chr.toUtf8))
            continue

        elif chr == '=':
            result.add((HAssign, chr.toUtf8))
            continue

        elif chr == '+':
            result.add((HAdd, chr.toUtf8))
            continue

        # TODO: Math
        elif chr == '-':
            result.add((HSub, chr.toUtf8))
            continue

        else:
            raise newException(HclSyntaxError, fmt"Encountered unexpected character '{chr}'", srcLoc)


when isMainModule:
    echo "HCL Lexer"
    var strm = newStreamerFromFile("example.hcl")
    let hcl = lex(strm)

    echo hcl