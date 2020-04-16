## 
## Tests for the HCL lexer
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import unittest

import nim_hcl/lexer
import nim_hcl/streamer

suite "HCL lexer tests":
    var strm = newStreamerFromFile("example.hcl")
    let lexed = lex(strm)
        
    test "Lexer parses comments properly":
        check:
            lexed[0].kind == HComment
            lexed[0].token == "# Allow tokens to look up their own properties"

    test "Lexer parses ident tokens properly":
        check:
            lexed[1].kind == HIdent
            lexed[1].token == "path"

    test "Lexer parses string tokens properly":
        check:
            lexed[2].kind == HString
            lexed[2].token == "auth/token/lookup-self"
    
    test "Parses { properly":
        check:
            lexed[3].kind == HLBrace
            lexed[3].token == "{"

    test "Parses assignments properly":
        check:
            lexed[5].kind == HAssign
            lexed[5].token == "="

    test "Parses [ properly":
        check:
            lexed[6].kind == HLBrack
            lexed[6].token == "["

    test "Parses ] properly":
        check:
            lexed[8].kind == HRBrack
            lexed[8].token == "]"

    test "Parses } properly":
        check:
            lexed[9].kind == HRBrace
            lexed[9].token == "}"