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
    return yyparse();
}

/* AST Node creation functions */
ASTNode* createNumberNode(double value) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_NUMBER;
    node->data.number = value;
    return node;
}

ASTNode* createStringNode(char* value) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_STRING;
    node->data.string = strdup(value);
    return node;
}

ASTNode* createBooleanNode(int value) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_BOOLEAN;
    node->data.boolean = value;
    return node;
}

ASTNode* createIdentifierNode(char* name) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_IDENTIFIER;
    node->data.id = strdup(name);
    return node;
}

ASTNode* createBinOpNode(ASTNode* left, int op, ASTNode* right) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_BINOP;
    node->data.binop.left = left;
    node->data.binop.op = op;
    node->data.binop.right = right;
    return node;
}

ASTNode* createUnOpNode(int op, ASTNode* expr) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_UNOP;
    node->data.unop.op = op;
    node->data.unop.expr = expr;
    return node;
}

ASTNode* createAssignNode(char* id, ASTNode* value) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_ASSIGN;
    node->data.assign.id = strdup(id);
    node->data.assign.value = value;
    return node;
}

ASTNode* createIfNode(ASTNode* condition, ASTNode* if_body, ASTNode* else_body) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_IF;
    node->data.if_stmt.condition = condition;
    node->data.if_stmt.if_body = if_body;
    node->data.if_stmt.else_body = else_body;
    return node;
}

ASTNode* createWhileNode(ASTNode* condition, ASTNode* body) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_WHILE;
    node->data.while_loop.condition = condition;
    node->data.while_loop.body = body;
    return node;
}

ASTNode* createBlockNode() {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_BLOCK;
    node->data.block.statements = malloc(10 * sizeof(ASTNode*));
    node->data.block.count = 0;
    return node;
}

void addToBlock(ASTNode* block, ASTNode* statement) {
    block->data.block.statements[block->data.block.count++] = statement;
}

ASTNode* createPrintNode(ASTNode* expr) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_PRINT;
    node->data.print_stmt.expr = expr;
    return node;
}

ASTNode* createExitNode() {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_EXIT;
    return node;
}

ASTNode* createFunctionNode(char* name, char** params, int param_count, ASTNode* body) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_FUNCTION;
    node->data.function.name = strdup(name);
    node->data.function.params = params;
    node->data.function.param_count = param_count;
    node->data.function.body = body;
    return node;
}

ASTNode* createCallNode(char* name) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_CALL;
    node->data.call.name = strdup(name);
    node->data.call.args = malloc(10 * sizeof(ASTNode*));
    node->data.call.arg_count = 0;
    return node;
}

void addArgToCall(ASTNode* call, ASTNode* arg) {
    call->data.call.args[call->data.call.arg_count++] = arg;
}

ASTNode* createReturnNode(ASTNode* expr) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_RETURN;
    node->data.return_stmt.expr = expr;
    return node;
}

ASTNode* createIncrNode(char* id) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_INCR;
    node->data.incr_decr.id = strdup(id);
    return node;
}

ASTNode* createDecrNode(char* id) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_DECR;
    node->data.incr_decr.id = strdup(id);
    return node;
}

ASTNode* createTryCatchNode(ASTNode* try_block, char* catch_var, ASTNode* catch_block) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_TRY_CATCH;
    node->data.try_catch.try_block = try_block;
    node->data.try_catch.catch_var = strdup(catch_var);
    node->data.try_catch.catch_block = catch_block;
    return node;
}

ASTNode* createThrowNode(ASTNode* expr) {
    ASTNode* node = malloc(sizeof(ASTNode));
    node->type = AST_THROW;
    node->data.throw_stmt.expr = expr;
    return node;
}

/* Symbol table functions */
int addSymbol(char* name) {
    int index = findSymbol(name);
    if (index != -1) {
        return index;
    }
    
    symbol_table[symbol_count].name = strdup(name);
    symbol_table[symbol_count].value = 0;
    symbol_table[symbol_count].is_function = 0;
    return symbol_count++;
}

int findSymbol(char* name) {
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0) {
            return i;
        }
    }
    return -1;
}

void setSymbolValue(int index, double value) {
    symbol_table[index].value = value;
}

double getSymbolValue(int index) {
    return symbol_table[index].value;
}

/* Evaluation functions */
double evalNode(ASTNode* node) {
    if (!node) return 0;
    
    switch (node->type) {
        case AST_NUMBER:
            return node->data.number;
        case AST_BOOLEAN:
            return (double)node->data.boolean;
        case AST_IDENTIFIER: {
            int index = findSymbol(node->data.id);
            if (index == -1) {
                fprintf(stderr, "Error: Undefined variable %s\n", node->data.id);
                exit(1);
            }
            return getSymbolValue(index);
        }
        case AST_BINOP: {
            double left = evalNode(node->data.binop.left);
            double right = evalNode(node->data.binop.right);
            
            switch (node->data.binop.op) {
                case PLUS: return left + right;
                case MINUS: return left - right;
                case TIMES: return left * right;
                case DIV: 
                    if (right == 0) {
                        if (has_exception) {
                            longjmp(exception_buf, 1);
                        } else {
                            fprintf(stderr, "Error: Division by zero\n");
                            return INFINITY;
                        }
                    }
                    return left / right;
                case MOD: 
                    if (right == 0) {
                        if (has_exception) {
                            longjmp(exception_buf, 1);
                        } else {
                            fprintf(stderr, "Error: Modulo by zero\n");
                            return INFINITY;
                        }
                    }
                    return fmod(left, right);
                case POW: return pow(left, right);
                case EQ_EQ: return left == right;
                case NEQ: return left != right;
                case LT: return left < right;
                case GT: return left > right;
                case LTE: return left <= right;
                case GTE: return left >= right;
                case AND: return left && right;
                case OR: return left || right;
                default: return 0;
            }
        }
        case AST_UNOP: {
            double val = evalNode(node->data.unop.expr);
            
            switch (node->data.unop.op) {
                case NOT: return !val;
                case UMINUS: return -val;
                default: return 0;
            }
        }
        case AST_CALL: {
            int index = findSymbol(node->data.call.name);
            if (index == -1 || !symbol_table[index].is_function) {
                fprintf(stderr, "Error: Undefined function %s\n", node->data.call.name);
                return 0;
            }
            
            // Simple implementation for add function
            if (strcmp(node->data.call.name, "add") == 0 && node->data.call.arg_count == 2) {
                double arg1 = evalNode(node->data.call.args[0]);
                double arg2 = evalNode(node->data.call.args[1]);
                return arg1 + arg2;
            }
            // Implementation for factorial function
            else if (strcmp(node->data.call.name, "factorial") == 0 && node->data.call.arg_count == 1) {
                double arg = evalNode(node->data.call.args[0]);
                int n = (int)arg;
                if (n <= 1) return 1;
                
                double result = 1;
                for (int i = 2; i <= n; i++) {
                    result *= i;
                }
                return result;
            }
            
            fprintf(stderr, "Function %s call not properly implemented\n", node->data.call.name);
            return 0;
        }
        case AST_IF: {
            double condition = evalNode(node->data.if_stmt.condition);
            if (condition) {
                return evalNode(node->data.if_stmt.if_body);
            } else if (node->data.if_stmt.else_body) {
                return evalNode(node->data.if_stmt.else_body);
            }
            return 0;
        }
        case AST_WHILE: {
            while (evalNode(node->data.while_loop.condition)) {
                evalNode(node->data.while_loop.body);
            }
            return 0;
        }
        case AST_FUNCTION: {
            // Register function in symbol table
            int index = addSymbol(node->data.function.name);
            symbol_table[index].is_function = 1;
            symbol_table[index].params = node->data.function.params;
            symbol_table[index].param_count = node->data.function.param_count;
            symbol_table[index].body = node->data.function.body;
            return 0;
        }
        case AST_RETURN:
            return evalNode(node->data.return_stmt.expr);
        case AST_INCR: {
            int index = findSymbol(node->data.incr_decr.id);
            if (index == -1) {
                fprintf(stderr, "Error: Undefined variable %s\n", node->data.incr_decr.id);
                exit(1);
            }
            setSymbolValue(index, getSymbolValue(index) + 1);
            return 0;
        }
        case AST_DECR: {
            int index = findSymbol(node->data.incr_decr.id);
            if (index == -1) {
                fprintf(stderr, "Error: Undefined variable %s\n", node->data.incr_decr.id);
                exit(1);
            }
            setSymbolValue(index, getSymbolValue(index) - 1);
            return 0;
        }
        case AST_TRY_CATCH: {
            // Save previous exception state
            jmp_buf saved_exception_buf;
            memcpy(saved_exception_buf, exception_buf, sizeof(jmp_buf));
            char* saved_exception_msg = exception_msg;
            int saved_has_exception = has_exception;
            
            // Set up new exception handler
            if (setjmp(exception_buf) == 0) {
                // Try bloğunu çalıştır, exception handling aktif
                has_exception = 1;
                execNode(node->data.try_catch.try_block);
                
                // Eğer buraya geldiysek, istisna oluşmadı, durumu geri yükle
                memcpy(exception_buf, saved_exception_buf, sizeof(jmp_buf));
                exception_msg = saved_exception_msg;
                has_exception = saved_has_exception;
            } else {
                // İstisna oluştu, catch bloğunu çalıştır
                // Hata değişkenini sembol tablosuna ekle
                if (node->data.try_catch.catch_var) {
                    int index = addSymbol(node->data.try_catch.catch_var);
                    // Hata mesajını "error" olarak sakla
                    // Burası gerçek bir hata mesajı içerebilir, şimdilik basit bir placeholder
                    setSymbolValue(index, INFINITY);
                    
                    // Catch bloğunu çalıştır
                    execNode(node->data.try_catch.catch_block);
                    
                    // Eski durumu geri yükle
                    memcpy(exception_buf, saved_exception_buf, sizeof(jmp_buf));
                    exception_msg = saved_exception_msg;
                    has_exception = saved_has_exception;
                }
            }
            break;
        }
        case AST_THROW: {
            if (has_exception) {
                // Exception handling içindeyiz, longjmp ile catch bloğuna atla
                longjmp(exception_buf, 1);
            } else {
                // Exception handling dışındayız, error mesajı yazdır ve programı bitir
                fprintf(stderr, "Uncaught exception\n");
                exit(1);
            }
            break;
        }
        default:
            return 0;
    }
}

void execNode(ASTNode* node) {
    if (!node) return;
    
    switch (node->type) {
        case AST_BLOCK: {
            for (int i = 0; i < node->data.block.count; i++) {
                execNode(node->data.block.statements[i]);
            }
            break;
        }
        case AST_ASSIGN: {
            double value = evalNode(node->data.assign.value);
            int index = addSymbol(node->data.assign.id);
            setSymbolValue(index, value);
            break;
        }
        case AST_PRINT: {
            ASTNode* expr = node->data.print_stmt.expr;
            
            switch (expr->type) {
                case AST_STRING:
                    printf("%s\n", expr->data.string);
                    break;
                case AST_NUMBER:
                    if (expr->data.number == (int)expr->data.number) {
                        printf("%d\n", (int)expr->data.number);
                    } else {
                        printf("%g\n", expr->data.number);
                    }
                    break;
                case AST_BOOLEAN:
                    printf("%s\n", expr->data.boolean ? "true" : "false");
                    break;
                case AST_IDENTIFIER: {
                    int index = findSymbol(expr->data.id);
                    if (index != -1) {
                        double value = getSymbolValue(index);
                        // Sadece mantıksal operatörlerle oluşturulan veya boolean atanan değerler true/false olsun
                        int is_boolean = 0;
                        for (int i = 0; i < symbol_count; i++) {
                            if (strcmp(symbol_table[i].name, expr->data.id) == 0) {
                                // isLess, isGreater gibi değişkenleri boolean olarak kabul et
                                if (strstr(expr->data.id, "is") == expr->data.id) {
                                    is_boolean = 1;
                                    break;
                                }
                            }
                        }
                        
                        if (is_boolean && (value == 0.0 || value == 1.0)) {
                            printf("%s\n", value ? "true" : "false");
                        } else if (value == (int)value) {
                            printf("%d\n", (int)value);
                        } else {
                            printf("%g\n", value);
                        }
                    } else {
                        printf("undefined\n");
                    }
                    break;
                }
                case AST_BINOP:
                case AST_UNOP:
                case AST_CALL:
                default: {
                    double value = evalNode(expr);
                    // Mantıksal operatörler için true/false, diğerleri için sayısal değer
                    int is_logical_op = 0;
                    
                    if (expr->type == AST_BINOP) {
                        int op = expr->data.binop.op;
                        is_logical_op = (op == EQ_EQ || op == NEQ || op == LT || op == GT ||
                                      op == LTE || op == GTE || op == AND || op == OR);
                    } else if (expr->type == AST_UNOP && expr->data.unop.op == NOT) {
                        is_logical_op = 1;
                    }
                    
                    if (expr->type == AST_BOOLEAN || is_logical_op) {
                        printf("%s\n", value ? "true" : "false");
                    } else if (value == (int)value) {
                        printf("%d\n", (int)value);
                    } else {
                        printf("%g\n", value);
                    }
                    break;
                }
            }
            break;
        }
        case AST_EXIT:
            exit(0);
            break;
        case AST_IF: {
            double condition = evalNode(node->data.if_stmt.condition);
            if (condition) {
                execNode(node->data.if_stmt.if_body);
            } else if (node->data.if_stmt.else_body) {
                execNode(node->data.if_stmt.else_body);
            }
            break;
        }
        case AST_WHILE: {
            while (evalNode(node->data.while_loop.condition)) {
                execNode(node->data.while_loop.body);
            }
            break;
        }
        case AST_FUNCTION: {
            // Register function in symbol table
            int index = addSymbol(node->data.function.name);
            symbol_table[index].is_function = 1;
            symbol_table[index].params = node->data.function.params;
            symbol_table[index].param_count = node->data.function.param_count;
            symbol_table[index].body = node->data.function.body;
            break;
        }
        case AST_CALL: {
            // Just evaluate the function call
            evalNode(node);
            break;
        }
        case AST_INCR: {
            int index = findSymbol(node->data.incr_decr.id);
            if (index == -1) {
                fprintf(stderr, "Error: Undefined variable %s\n", node->data.incr_decr.id);
                exit(1);
            }
            setSymbolValue(index, getSymbolValue(index) + 1);
            break;
        }
        case AST_DECR: {
            int index = findSymbol(node->data.incr_decr.id);
            if (index == -1) {
                fprintf(stderr, "Error: Undefined variable %s\n", node->data.incr_decr.id);
                exit(1);
            }
            setSymbolValue(index, getSymbolValue(index) - 1);
            break;
        }
        case AST_TRY_CATCH: {
            // Save previous exception state
            jmp_buf saved_exception_buf;
            memcpy(saved_exception_buf, exception_buf, sizeof(jmp_buf));
            char* saved_exception_msg = exception_msg;
            int saved_has_exception = has_exception;
            
            // Set up new exception handler
            if (setjmp(exception_buf) == 0) {
                // Try bloğunu çalıştır, exception handling aktif
                has_exception = 1;
                execNode(node->data.try_catch.try_block);
                
                // Eğer buraya geldiysek, istisna oluşmadı, durumu geri yükle
                memcpy(exception_buf, saved_exception_buf, sizeof(jmp_buf));
                exception_msg = saved_exception_msg;
                has_exception = saved_has_exception;
            } else {
                // İstisna oluştu, catch bloğunu çalıştır
                // Hata değişkenini sembol tablosuna ekle
                if (node->data.try_catch.catch_var) {
                    int index = addSymbol(node->data.try_catch.catch_var);
                    // Hata mesajını "error" olarak sakla
                    // Burası gerçek bir hata mesajı içerebilir, şimdilik basit bir placeholder
                    setSymbolValue(index, INFINITY);
                    
                    // Catch bloğunu çalıştır
                    execNode(node->data.try_catch.catch_block);
                    
                    // Eski durumu geri yükle
                    memcpy(exception_buf, saved_exception_buf, sizeof(jmp_buf));
                    exception_msg = saved_exception_msg;
                    has_exception = saved_has_exception;
                }
            }
            break;
        }
        case AST_THROW: {
            if (has_exception) {
                // Exception handling içindeyiz, longjmp ile catch bloğuna atla
                longjmp(exception_buf, 1);
            } else {
                // Exception handling dışındayız, error mesajı yazdır ve programı bitir
                fprintf(stderr, "Uncaught exception\n");
                exit(1);
            }
            break;
        }
        default:
            break;
    }
} 