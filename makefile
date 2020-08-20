SHELL = /bin/bash

a.out: lex.yy.c
	gcc -Wall lex.yy.c -lfl

lex.yy.c: syllables.lex
	flex -i syllables.lex

clean:
	rm a.out
	rm lex.yy.c
