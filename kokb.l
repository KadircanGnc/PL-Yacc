%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"

void yyerror(const char* s);
%}

%option noyywrap
%option yylineno

%%

[ \t\r\n]+                /* Boşlukları atla */
"//".*                    /* Tek satırlık yorumları atla */

"print"                   { return PRINT; }
"exit"                    { return EXIT; }
"if"                      { return IF; }
"else"                    { return ELSE; }
"while"                   { return WHILE; }
"function"                { return FUNCTION; }
"return"                  { return RETURN; }
"try"                     { return TRY; }
"catch"                   { return CATCH; }
"throw"                   { return THROW; }

"true"                    { yylval.boolean = 1; return BOOLEAN; }
"false"                   { yylval.boolean = 0; return BOOLEAN; }

[0-9]+                    { yylval.number = atoi(yytext); return NUMBER; }
[0-9]+\.[0-9]+            { yylval.number = atof(yytext); return NUMBER; }

\"[^\"]*\"                { 
                            /* Tırnak işaretlerini kaldır */
                            yytext[strlen(yytext) - 1] = '\0';
                            yylval.string = strdup(yytext + 1);
                            return STRING;
                         }

[a-zA-Z_][a-zA-Z0-9_]*    { yylval.identifier = strdup(yytext); return IDENTIFIER; }

"+"                       { return PLUS; }
"-"                       { return MINUS; }
"*"                       { return TIMES; }
"/"                       { return DIV; }
"%"                       { return MOD; }
"^"                       { return POW; }
"++"                      { return INCR; }
"--"                      { return DECR; }

"=="                      { return EQ_EQ; }
"!="                      { return NEQ; }
"<"                       { return LT; }
">"                       { return GT; }
"<="                      { return LTE; }
">="                      { return GTE; }

"&&"                      { return AND; }
"||"                      { return OR; }
"!"                       { return NOT; }

"="                       { return EQ; }

"("                       { return '('; }
")"                       { return ')'; }
"{"                       { return '{'; }
"}"                       { return '}'; }

";"                       { return ';'; }
","                       { return ','; }

.                         { yyerror("Tanınmayan karakter"); }

%%
