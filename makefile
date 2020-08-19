SHELL = /bin/bash

a.out: lex.yy.c
	gcc -Wall lex.yy.c -lfl

lex.yy.c: syllabe.lex
	flex -i syllabe.lex

clean:
	rm a.out
	rm lex.yy.c