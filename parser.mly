%{ open Ast %}

%token LPAREN RPAREN LBRACE RBRACE SEMI COMMA PLUS MINUS TIMES DIVIDE
%token ASSIGN EQ NEQ LT LEQ GT GEQ IF ELSE FOR WHILE RETURN INT PITCH SOUND VOID EOF
%token <int> LITERAL
%token <string> ID

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left EQ NEQ
%left LT GT LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE

%start program
%type <Ast.program> program

%%

program:
    /* nothing */   { [], [] }
    | program vdecl { ($2 :: fst $1), snd $1 }
    | program fdecl { fst $1, ($2 :: snd $1) }

vdecl_list:
    /* nothing */         { [] }
    | vdecl_list vdecl    { $2 :: $1  }
    
vdecl:
    typeConst ID SEMI			
            { { vartype = $1;
                varname = $2 } } 

fdecl:
	typeConst ID LPAREN formals_opt RPAREN LBRACE vdecl_list stmt_list RBRACE
                    { { rettype = $1;
                        fname = $2;
						formals = $4;
						locals = List.rev $7;
						body = List.rev $8 } }

formals_opt:
    /* nothing */           { [] }
    | formal_list           { List.rev $1 }

formal_list:
    formal_decl                         { [$1] }
    | formal_list COMMA formal_decl     { $3 :: $1 }

formal_decl:
     typeConst ID
             { { formname = $2;
                 formtype = $1; } }          
                    
typeConst:
    INT                     { Int }
    | VOID                  { Void }
    | PITCH                 { Pitch }
    | SOUND                 { Sound }

stmt_list:
    /* nothing */             { [] }
    | ID                      { $1 }




































































expr:
	ID									{ Id($1) }
	| LPAREN expr RPAREN				{ Expr($2) }
	| ID LPAREN actuals_opt RPAREN		{ Call($1, $3) }
	| ID LBRACK expr RBRACK				{ Array($1, $3) }


 
