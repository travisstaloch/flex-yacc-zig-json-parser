%{

// bison file: json-parser.y
#include <stdio.h>
#include "parser.h"
extern int yylineno;
extern char *yytext;
extern void start_obj(ParseState*);
extern void end_obj(ParseState*);
extern void start_arr(ParseState*);
extern void arr_value(ParseState*);
extern void end_arr(ParseState*);
extern void member(ParseState*, const char*);
extern void string(ParseState*, const char*);
extern void decimal(ParseState*, const char*);
extern void integer(ParseState*, const char*);
extern void vtrue(ParseState*);
extern void vfalse(ParseState*);
extern void vnull(ParseState*);
%}

%token LCURLY RCURLY LBRACE RBRACE COMMA COLON
%token VTRUE VFALSE VNULL
%token STRING DECIMAL INTEGER;

%start json
%parse-param {ParseState *parse_state}
%locations

%%

json: value
     ;

value: object
     | STRING  { string(parse_state, yytext); }
     | DECIMAL { decimal(parse_state, yytext); }
     | INTEGER { integer(parse_state, yytext); }
     | array
     | VTRUE   { vtrue(parse_state); }
     | VFALSE  { vfalse(parse_state); }
     | VNULL   { vnull(parse_state); }
     ;

object: LCURLY { start_obj(parse_state); } RCURLY { end_obj(parse_state); }
     |  LCURLY { start_obj(parse_state); } members RCURLY { end_obj(parse_state); }
     ;

members: member
     | members COMMA member
     ;

member: STRING { member(parse_state, yytext); } COLON value
     ;

array: LBRACE { start_arr(parse_state); } RBRACE { end_arr(parse_state); }
     | LBRACE { start_arr(parse_state); } values RBRACE { end_arr(parse_state); }
     ;

values: { arr_value(parse_state); } value 
     | values COMMA { arr_value(parse_state); } value
     ;

%%

void
yyerror(YYLTYPE *location, ParseState *parse_state, const char *s)
{
  fprintf(stderr,"%s:%d:%d: error: %s\n", parse_state->file_path, yyloc.first_line+1, yyloc.first_column+1, s);
}