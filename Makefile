SCANNER := lex
SCANNER_PARAMS := lex.l
PARSER := yacc
PARSER_PARAMS := -d syntax.y

all: compile translate clean

compile:
		$(SCANNER) $(SCANNER_PARAMS)
		$(PARSER) $(PARSER_PARAMS)
		g++ -o glf y.tab.c -ll

run: 	glf
		clear
		compile
		translate

debug:	PARSER_PARAMS += -Wcounterexamples
debug: 	all

translate: glf
		./glf < ex.pcd

clean:
	rm y.tab.c
	rm y.tab.h
	rm lex.yy.c
	rm glf