%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <setjmp.h>

void yyerror(const char *s);
int yylex(void);
extern int yylineno;
extern char* yytext;

// Exception handling
jmp_buf exception_buf;
char* exception_msg = NULL;
int has_exception = 0;

typedef struct {
    char* name;
    double value;
    int is_function;
    char** params;
    int param_count;
    struct ASTNode* body;
} Symbol;

typedef enum {
    AST_NUMBER,
    AST_STRING,
    AST_BOOLEAN,
    AST_IDENTIFIER,
    AST_BINOP,
    AST_UNOP,
    AST_ASSIGN,
    AST_IF,
    AST_WHILE,
    AST_BLOCK,
    AST_PRINT,
    AST_EXIT,
    AST_FUNCTION,
    AST_CALL,
    AST_RETURN,
    AST_INCR,
    AST_DECR,
    AST_TRY_CATCH,
    AST_THROW
} NodeType;

typedef struct ASTNode {
    NodeType type;
    union {
        double number;
        char* string;
        int boolean;
        char* id;
        
        struct {
            struct ASTNode* left;
            int op;
            struct ASTNode* right;
        } binop;
        
        struct {
            int op;
            struct ASTNode* expr;
        } unop;
        
        struct {
            char* id;
            struct ASTNode* value;
        } assign;
        
        struct {
            struct ASTNode* condition;
            struct ASTNode* if_body;
            struct ASTNode* else_body;
        } if_stmt;
        
        struct {
            struct ASTNode* condition;
            struct ASTNode* body;
        } while_loop;
        
        struct {
            struct ASTNode** statements;
            int count;
        } block;
        
        struct {
            struct ASTNode* expr;
        } print_stmt;
        
        struct {
            char* name;
            char** params;
            int param_count;
            struct ASTNode* body;
        } function;
        
        struct {
            char* name;
            struct ASTNode** args;
            int arg_count;
        } call;
        
        struct {
            struct ASTNode* expr;
        } return_stmt;
        
        struct {
            char* id;
        } incr_decr;
        
        struct {
            struct ASTNode* try_block;
            char* catch_var;
            struct ASTNode* catch_block;
        } try_catch;
        
        struct {
            struct ASTNode* expr;
        } throw_stmt;
    } data;
} ASTNode;

#define SYMBOL_TABLE_SIZE 100
Symbol symbol_table[SYMBOL_TABLE_SIZE];
int symbol_count = 0;

ASTNode* createNumberNode(double value);
ASTNode* createStringNode(char* value);
ASTNode* createBooleanNode(int value);
ASTNode* createIdentifierNode(char* name);
ASTNode* createBinOpNode(ASTNode* left, int op, ASTNode* right);
ASTNode* createUnOpNode(int op, ASTNode* expr);
ASTNode* createAssignNode(char* id, ASTNode* value);
ASTNode* createIfNode(ASTNode* condition, ASTNode* if_body, ASTNode* else_body);
ASTNode* createWhileNode(ASTNode* condition, ASTNode* body);
ASTNode* createBlockNode();
void addToBlock(ASTNode* block, ASTNode* statement);
ASTNode* createPrintNode(ASTNode* expr);
ASTNode* createExitNode();
ASTNode* createFunctionNode(char* name, char** params, int param_count, ASTNode* body);
ASTNode* createCallNode(char* name);
void addArgToCall(ASTNode* call, ASTNode* arg);
ASTNode* createReturnNode(ASTNode* expr);
ASTNode* createIncrNode(char* id);
ASTNode* createDecrNode(char* id);
ASTNode* createTryCatchNode(ASTNode* try_block, char* catch_var, ASTNode* catch_block);
ASTNode* createThrowNode(ASTNode* expr);

double evalNode(ASTNode* node);
void execNode(ASTNode* node);

int addSymbol(char* name);
int findSymbol(char* name);
void setSymbolValue(int index, double value);
double getSymbolValue(int index);
%}

%union {
    double number;
    char* string;
    int boolean;
    char* identifier;
    struct ASTNode* node;
}

%token <number> NUMBER
%token <string> STRING
%token <boolean> BOOLEAN
%token <identifier> IDENTIFIER
%token PRINT EXIT IF ELSE WHILE FUNCTION RETURN
%token TRY CATCH THROW
%token EQ PLUS_EQ MINUS_EQ TIMES_EQ DIV_EQ MOD_EQ POW_EQ
%token OR AND NOT
%token EQ_EQ NEQ LT GT LTE GTE
%token PLUS MINUS TIMES DIV MOD POW
%token INCR DECR

%type <node> program statement statements expr block
%type <node> if_statement while_statement function_statement return_statement
%type <node> assignment_statement print_statement exit_statement incr_decr_statement
%type <node> function_call try_catch_statement

%left OR
%left AND
%nonassoc EQ_EQ NEQ
%nonassoc LT GT LTE GTE
%left PLUS MINUS
%left TIMES DIV MOD
%right POW
%right NOT
%right UMINUS

%%

program
    : statements { execNode($1); }
    ;

statements
    : statement { $$ = createBlockNode(); addToBlock($$, $1); }
    | statements statement { addToBlock($1, $2); $$ = $1; }
    ;

statement
    : assignment_statement ';' { $$ = $1; }
    | print_statement ';' { $$ = $1; }
    | exit_statement ';' { $$ = $1; }
    | if_statement { $$ = $1; }
    | while_statement { $$ = $1; }
    | block { $$ = $1; }
    | function_statement { $$ = $1; }
    | return_statement ';' { $$ = $1; }
    | incr_decr_statement ';' { $$ = $1; }
    | function_call ';' { $$ = $1; }
    | try_catch_statement { $$ = $1; }
    | THROW expr ';' { $$ = createThrowNode($2); }
    ;

assignment_statement
    : IDENTIFIER EQ expr { $$ = createAssignNode($1, $3); }
    ;

print_statement
    : PRINT expr { $$ = createPrintNode($2); }
    ;

exit_statement
    : EXIT { $$ = createExitNode(); }
    ;

if_statement
    : IF '(' expr ')' block { $$ = createIfNode($3, $5, NULL); }
    | IF '(' expr ')' block ELSE block { $$ = createIfNode($3, $5, $7); }
    | IF '(' expr ')' block ELSE if_statement { $$ = createIfNode($3, $5, $7); }
    ;

while_statement
    : WHILE '(' expr ')' block { $$ = createWhileNode($3, $5); }
    ;

block
    : '{' statements '}' { $$ = $2; }
    | '{' '}' { $$ = createBlockNode(); }
    ;

function_statement
    : FUNCTION IDENTIFIER '(' ')' block {
        char** params = NULL;
        $$ = createFunctionNode($2, params, 0, $5);
    }
    | FUNCTION IDENTIFIER '(' IDENTIFIER ')' block {
        char** params = malloc(sizeof(char*));
        params[0] = $4;
        $$ = createFunctionNode($2, params, 1, $6);
    }
    | FUNCTION IDENTIFIER '(' IDENTIFIER ',' IDENTIFIER ')' block {
        char** params = malloc(2 * sizeof(char*));
        params[0] = $4;
        params[1] = $6;
        $$ = createFunctionNode($2, params, 2, $8);
    }
    ;

return_statement
    : RETURN expr { $$ = createReturnNode($2); }
    ;

incr_decr_statement
    : IDENTIFIER INCR { $$ = createIncrNode($1); }
    | IDENTIFIER DECR { $$ = createDecrNode($1); }
    ;

function_call
    : IDENTIFIER '(' ')' {
        $$ = createCallNode($1);
    }
    | IDENTIFIER '(' expr ')' {
        $$ = createCallNode($1);
        addArgToCall($$, $3);
    }
    | IDENTIFIER '(' expr ',' expr ')' {
        $$ = createCallNode($1);
        addArgToCall($$, $3);
        addArgToCall($$, $5);
    }
    ;

try_catch_statement
    : TRY block CATCH '(' IDENTIFIER ')' block {
        $$ = createTryCatchNode($2, $5, $7);
    }
    ;

expr
    : NUMBER { $$ = createNumberNode($1); }
    | STRING { $$ = createStringNode($1); }
    | BOOLEAN { $$ = createBooleanNode($1); }
    | IDENTIFIER { $$ = createIdentifierNode($1); }
    | function_call { $$ = $1; }
    | expr PLUS expr { $$ = createBinOpNode($1, PLUS, $3); }
    | expr MINUS expr { $$ = createBinOpNode($1, MINUS, $3); }
    | expr TIMES expr { $$ = createBinOpNode($1, TIMES, $3); }
    | expr DIV expr { $$ = createBinOpNode($1, DIV, $3); }
    | expr MOD expr { $$ = createBinOpNode($1, MOD, $3); }
    | expr POW expr { $$ = createBinOpNode($1, POW, $3); }
    | expr EQ_EQ expr { $$ = createBinOpNode($1, EQ_EQ, $3); }
    | expr NEQ expr { $$ = createBinOpNode($1, NEQ, $3); }
    | expr LT expr { $$ = createBinOpNode($1, LT, $3); }
    | expr GT expr { $$ = createBinOpNode($1, GT, $3); }
    | expr LTE expr { $$ = createBinOpNode($1, LTE, $3); }
    | expr GTE expr { $$ = createBinOpNode($1, GTE, $3); }
    | expr AND expr { $$ = createBinOpNode($1, AND, $3); }
    | expr OR expr { $$ = createBinOpNode($1, OR, $3); }
    | NOT expr { $$ = createUnOpNode(NOT, $2); }
    | MINUS expr %prec UMINUS { $$ = createUnOpNode(UMINUS, $2); }
    | '(' expr ')' { $$ = $2; }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error at line %d: %s\n", yylineno, s);
}

int main() {
    return yyparse();
}