## 
## Types for the HCL parser
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##

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

type
    AstNodeType = enum
        AstNodeLeaf,    # Single, no children
        AstNodeBranch   # Children

    Leaf = object
        comment: string

    AstNode* = ref object
        case nodeType*: AstNodeType
        of AstNodeLeaf:
            nodeLeaf: Leaf
        of AstNodeBranch:
            branchLeaf: Leaf
            children: seq[AstNode]
