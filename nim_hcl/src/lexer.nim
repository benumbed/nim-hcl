## 
## Lexer for HCL
## NOTE: This uses Unicode runes (for the future), but isn't really unicode compatible yet
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import strformat
import unicode as uc

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
    return (int(c) <= int(Rune('9')) and int(c) >= int(Rune('0')))


proc readIdentifier(stream: Stream, loc: var SourceLocation): HclToken =
    ## Reads an identifier from the stream and returns a new token
    var token: string

    const altRunes = @[Rune('-'), Rune('.')]

    while true:
        let chr = uc.Rune(stream.readChar())
        loc.column.inc

        if chr.isAlpha or chr.isDigit or chr in altRunes:
            token.add(chr)
            continue
        
        break

    return (HIdent, token)

proc readNumber(stream: Stream, loc: var SourceLocation): HclToken =
    ## Reads a number from the stream
    var number: string

    # TODO: Numeric validation and type selection
    while true:
        let chr = uc.Rune(stream.readChar())
        loc.column.inc

        if not(chr.isDigit or chr == Rune('x') or chr == Rune('.')):
            break
        
        number.add(chr)

    return (HNumber, number)


proc readComment(stream: Stream, loc: var SourceLocation): HclToken =
    ## Reads a comment from the stream
    var token: string
    # Note, we don't include the '#' in the token, because if we reproduce this, we'll add it during rendering

    while true:
        let chr = uc.Rune(stream.readChar())
        loc.column.inc
        if chr in EOL_CHARS or stream.atEnd:
            loc.line.inc
            loc.column = 0
            break
        
        token.add(chr)

    return (HComment, token)

proc readString(stream: Stream, loc: var SourceLocation): HclToken =
    ## Reads a quoted string from the stream
    var token: string
    const endChr = Rune('"')
    
    # Remove the leading "
    stream.setPosition(stream.getPosition+1)
    while true:
        let chr = uc.Rune(stream.readChar())
        loc.column.inc
        if chr == endChr:
            break
        
        token.add(chr)
    
    return (HString, token)


proc readHeredoc(stream: Stream, loc: var SourceLocation): HclToken =
    ## Reads a heredoc from the stream
    var heredoc: string
    var anchor: string

    const indentChar = Rune('-')

    var chr = Rune(stream.readChar())
    loc.column.inc
    if stream.readChar() != '<':
        loc.column.inc
        raise newException(HclSyntaxError, fmt"Expected second '<' in heredoc, got {chr}", loc)
    loc.column.inc

    # Read the anchor
    while true:
        chr = Rune(stream.readChar())
        loc.column.inc
        if chr in EOL_CHARS:
            loc.line.inc
            loc.column = 0
            break
        anchor.add(chr)

    if anchor == "":
        raise newException(HclSyntaxError, "Heredoc missing anchor text", loc)

    while true:
        if stream.peekStr(anchor.len) == anchor:
            loc.column.inc(anchor.len)
            break
        
        if stream.atEnd():
            raise newException(HclSyntaxError, "Encountered unexpected EOF while processing heredoc, no terminating anchor", loc)

        # TODO: Allow for '-' in heredoc
        heredoc.add(Rune(stream.readChar()))
    
    return (HHeredoc, heredoc)


proc lex*(stream: Stream): HclTokens =
    ## Analyzes `stream` and returns the tokens within
    var srcLoc = SourceLocation()
    srcLoc.line = 1

    while not stream.atEnd():
        # var chr = Rune(stream.peekChar())
        var chr = Rune(stream.peekChar())

        if chr.isWhiteSpace:
            stream.setPosition(stream.getPosition()+1)
            srcLoc.column.inc

            if chr in EOL_CHARS:
                srcLoc.line.inc
                srcLoc.column = 0
            continue

        elif chr in COMMENT_CHARS:
            result.add(stream.readComment(srcLoc))
            continue

        elif chr == Rune('"'):
            result.add(stream.readString(srcLoc))
            continue

        elif chr.isAlpha:
            result.add(stream.readIdentifier(srcLoc))
            continue

        elif chr.isDigit:
            result.add(stream.readNumber(srcLoc))
            continue

        # Operators
        
        chr = uc.Rune(stream.readChar())
        srcLoc.column.inc

        if chr == Rune('<'):
            result.add(stream.readHeredoc(srcLoc))
            continue

        elif chr == Rune('{'):
            result.add((HLBrace, chr.toUtf8))
            continue

        elif chr == Rune('}'):
            result.add((HRBrace, chr.toUtf8))
            continue

        elif chr == Rune('['):
            result.add((HLBrack, chr.toUtf8))
            continue

        elif chr == Rune(']'):
            result.add((HRBrack, chr.toUtf8))
            continue

        elif chr == Rune(','):
            result.add((HComma, chr.toUtf8))
            continue

        elif chr == Rune('='):
            result.add((HAssign, chr.toUtf8))
            continue

        elif chr == Rune('+'):
            result.add((HAdd, chr.toUtf8))
            continue

        elif chr == Rune('-'):
            result.add((HSub, chr.toUtf8))
            continue

        else:
            raise newException(HclSyntaxError, fmt"Encountered unexpected character '{chr}'", srcLoc)


when isMainModule:
    echo "HCL Lexer"
    let fs = newFileStream("example.hcl")
    let hcl = lex(fs)


    echo hcl