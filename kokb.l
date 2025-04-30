%{
#include "y.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int errorLineCounter = 1;
void yyerror(char *s);
%}

%%
"exit"                  { return EXIT_COMMAND; }
";"                     { return SEMICOLON; }
"print"                 { return PRINT; }
"+"                     { return PLUS; }
"-"                     { return MINUS; }
"*"                     { return MULTIPLY; }
"/"                     { return DIVIDE; }
"^"                     { return POWER; }
"="                     { return ASSIGN; }
"%"                     { return MODULE; }
"++"                    { return INCREMENT; }
"--"                    { return DECREMENT; }
"<"                     { return LESS_THAN; }
">"                     { return GREATER_THAN; }
">="                    { return GREATER_THAN_OR_EQUAL; }
"<="                    { return LESS_THAN_OR_EQUAL; }
"=="                    { return EQUALS; }
"!="                    { return NOT_EQUALS; }
"&&"                    { return AND; }
"||"                    { return OR; }
"!"                     { return NOT; }
"("                     { return LPAREN; }
")"                     { return RPAREN; }
"{"                     { return LBRACE; }
"}"                     { return RBRACE; }
"["                     { return LBRACKET; }
"]"                     { return RBRACKET; }
"if"                    { return IF; }
"else"                  { return ELSE; }
"else if"               { return ELSEIF; }
"while"                 { return WHILE; }
"true"                  { yylval.boolean = 1; return BOOLEAN; }
"false"                 { yylval.boolean = 0; return BOOLEAN; }
"def"                   { return FUNCTION_DEF; }
"return"                { return RETURN; }
[a-z][a-zA-Z0-9_]*      { yylval.id = strdup(yytext); return IDENTIFIER; }
[-]?[1-9][0-9]*|0       { yylval.num = atoi(yytext); return NUMBER; }
[-]?[0-9]*\.[0-9]+      { yylval.decimal = atof(yytext); return FLOAT; }
["].*["]                { 
                          yylval.string = malloc(yyleng - 1);
                          strncpy(yylval.string, yytext + 1, yyleng - 2);
                          yylval.string[yyleng - 2] = '\0';
                          return STRING;
                        }
[\/][\/].*              { /* Skip comments */ }
[\n]                    { errorLineCounter++; }
[ \t]+                  /* skip whitespace */
[\r\n]+                 { errorLineCounter++; } /* skip empty lines */
.                       { printf("ERROR: unexpected character '%s' at line %d\n", yytext, errorLineCounter); }
%%

int yywrap(void) {
    return 1;
}
