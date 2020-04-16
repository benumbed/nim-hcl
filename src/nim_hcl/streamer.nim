## 
## Stream manager for HCL lexer
## NOTE: This uses Unicode runes (for the future), but isn't really unicode compatible yet
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import streams
import unicode

type SourceLocation* = object
    line*: int
    column*: int

type 
    Streamer* = ref StreamerObj
    StreamerObj = object
        s*: Stream
        loc*: SourceLocation


proc newStreamerFromFile*(filePath: string): Streamer =
    ## Creates a new Streamer object from the provided `filePath`
    new(result)

    result.s = openFileStream(filePath)
    result.loc.line = 1

proc readRune*(strm: Streamer): Rune =
    ## Reads a unicode rune from a stream (not really, it reads a character and encodes it as a Rune)
    ## TODO: Implement actual unicode reading
    result = Rune(strm.s.readChar())
    strm.loc.column.inc

proc peekRune*(strm: Streamer): Rune = 
    ## Just wraps the stream character peek
    Rune(strm.s.peekChar())

proc resetColCount*(strm: Streamer) = 
    strm.loc.column = 0

proc incLineCount*(strm: Streamer, inc = 1) =
    ## Increment the line count
    strm.loc.line.inc(inc)
    strm.resetColCount

proc setPosition*(strm: Streamer, pos: int) = strm.s.setPosition(pos)
proc getPosition*(strm: Streamer): int = strm.s.getPosition()

proc incPosition*(strm: var Streamer, inc = 1) =
    ## Increments the position of the stream by `inc`.  NOTE: This does not look for newlines!
    strm.setPosition(strm.getPosition+inc)
    strm.loc.column.inc(inc)

proc atEnd*(strm: Streamer): bool = strm.s.atEnd
proc peekStr*(strm: Streamer, len: int): string = strm.s.peekStr(len)

proc `==`*(r1: Rune, c: char): bool = int(r1) == int(c)
proc `>=`*(r1: Rune, r2: Rune): bool = int(r1) >= int(r2)
proc `>=`*(r1: Rune, c: char): bool = int(r1) >= int(c)
proc `<=`*(r1: Rune, r2: Rune): bool = int(r1) <= int(r2)
proc `<=`*(r1: Rune, c: char): bool = int(r1) <= int(c)