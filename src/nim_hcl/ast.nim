## 
## AST for HCL
##
## (C) 2020 Benumbed (Nick Whalen) <benumbed@projectneutron.com> -- All Rights Reserved
##
import tables

import ./lexer
import ./types

type Ast = seq[AstNode]
