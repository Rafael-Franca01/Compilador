SCANNER := lex
SCANNER_PARAMS := lex.l
PARSER := yacc
PARSER_PARAMS := -d syntax.y

CPP_COMPILER := g++
C3A_OUTPUT_FILE := output.cpp
FINAL_EXEC := final_program

all: compile translate clean

compile:
	$(SCANNER) $(SCANNER_PARAMS)
	$(PARSER) $(PARSER_PARAMS)
	$(CPP_COMPILER) -o glf y.tab.c -ll

run: 	glf
	clear
	compile
	translate

debug: 	PARSER_PARAMS += -Wcounterexamples
debug: 	all

translate: glf
	./glf < ex.pcd

build: compile
	./glf < ex.pcd > $(C3A_OUTPUT_FILE)
	$(CPP_COMPILER) -o $(FINAL_EXEC) $(C3A_OUTPUT_FILE)
	./$(FINAL_EXEC)
	rm -f y.tab.c y.tab.h lex.yy.c glf $(C3A_OUTPUT_FILE) $(FINAL_EXEC)
	
	
clean:
	rm -f y.tab.c y.tab.h lex.yy.c glf $(C3A_OUTPUT_FILE) $(FINAL_EXEC)
