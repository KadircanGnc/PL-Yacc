kokb: lex.yy.c y.tab.c
	gcc -g lex.yy.c y.tab.c -o kokb -lm

lex.yy.c: y.tab.c kokb.l
	flex kokb.l

y.tab.c: kokb.y
	yacc -d kokb.y

run:
	./kokb < example.kokb

clean: 
	rm -rf lex.yy.c y.tab.c y.tab.h kokb kokb.dSYM

