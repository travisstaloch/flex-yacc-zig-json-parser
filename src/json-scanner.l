%{
// flex file: json-scanner.l
#include "parser.yy.h"

#define YY_USER_ACTION \
    yylloc.first_line = yylloc.last_line; \
    yylloc.first_column = yylloc.last_column; \
    for(int i = 0; yytext[i] != '\0'; i++) { \
        if(yytext[i] == '\n') { \
            ++yylloc.last_line; \
            yylloc.last_column = 0; \
        } \
        else { \
            ++yylloc.last_column; \
        } \
    }
%}

%option noyywrap
/* generate 8-bit scanner */
/*%option 8bit*/
/* generate batch scanner */
%option batch

EXP             [Ee][-+]?[0-9]+
ESCAPEDCHAR     \\["\\bfnrt/]
U               [\x80-\xbf]
U2              [\xc2-\xdf]
U3              [\xe0-\xef]
U4              [\xf0-\xf4]
UNESCAPEDCHAR   [ -!#-\[\]-~]|{U2}{U}|{U3}{U}{U}|{U4}{U}{U}{U}
HEX_DIGIT       [0-9a-f]
UNICODECHAR     \\u{HEX_DIGIT}{HEX_DIGIT}{HEX_DIGIT}{HEX_DIGIT}
CHAR            {UNESCAPEDCHAR}|{ESCAPEDCHAR}|{UNICODECHAR}
CHARS           {CHAR}+
DQUOTE          ["]

%%

"{"                     return LCURLY;
"}"                     return RCURLY;
"["                     return LBRACE;
"]"                     return RBRACE;
":"                     return COLON;
","                     return COMMA;
"true"                  return VTRUE;
"false"                 return VFALSE;
"null"                  return VNULL;
{DQUOTE}{DQUOTE} |
{DQUOTE}{CHARS}{DQUOTE} return STRING;
[0-9]+"."[0-9]*{EXP}?   return DECIMAL;
[0]|"-"?[1-9][0-9_\.]*  return INTEGER;
[ \t\n\r]               ;
.                       return -1;

%%
