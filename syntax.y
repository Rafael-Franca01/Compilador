%{
#include <iostream>
#include <string>
#include <map>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt = 0;
int contador_linha = 1;


struct atributos
{
	string label;
	string traducao;
	string tipo;
};

map<string, string> tabela_simbolos;
map<string, string> declaracoes_temp;

int yylex(void);
void yyerror(string);
string gentempcode();
%}

%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE
%token TK_MAIN TK_ID TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL
%token TK_FIM TK_ERROR

%start S

%left '+' '-'
%left '*' '/'

%%

S : TK_TIPO_INT TK_MAIN '(' ')' BLOCO
	{
		string codigo = "/*Compilador PCD*/\n"
						"#include <iostream>\n"
						"#include<string.h>\n"
						"#include<stdio.h>\n"
						"int main(void) {\n";

		for (auto &it : declaracoes_temp) {
			if (it.second == "int") {
				codigo += "\tint " + it.first + ";\n";
			} else if (it.second == "float") {
				codigo += "\tfloat " + it.first + ";\n";
			} else if (it.second == "boolean") {
			codigo += "\tbool " + it.first + ";\n";
			}
		}

		codigo += "\n";
		codigo += $5.traducao;
		codigo += "\treturn 0;\n}";

		cout << codigo << endl;
	}
	;

BLOCO : '{' COMANDOS '}'
	{ $$.traducao = $2.traducao; }
	;

COMANDOS : COMANDO COMANDOS
	{ $$.traducao = $1.traducao + $2.traducao; }
	| { $$.traducao = ""; }
	;

COMANDO : DECLARACAO
	| E ';' { $$ = $1; }
	;

DECLARACAO : TIPO TK_ID ';'
	{
		if (tabela_simbolos.count($2.label))
			yyerror("Erro: variável já declarada: " + $2.label);

		tabela_simbolos[$2.label] = $1.tipo;
		$$.traducao = "";
	}
	;

TIPO : TK_TIPO_INT    { $$.tipo = "int"; }
	 | TK_TIPO_FLOAT  { $$.tipo = "float"; }
	 | TK_TIPO_BOOL   { $$.tipo = "boolean"; }
	 ;

E : E '+' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '+'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " + " + $3.label + ";\n";
		$$.tipo = $1.tipo;
	}
	| E '-' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '-'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " - " + $3.label + ";\n";
		$$.tipo = $1.tipo;
	}
	| E '*' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '*'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " * " + $3.label + ";\n";
		$$.tipo = $1.tipo;
	}
	| E '/' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '/'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " / " + $3.label + ";\n";
		$$.tipo = $1.tipo;
	}
	| '(' E ')'
	{
		$$ = $2;
	}
	| TK_ID '=' E
	{
		if (!tabela_simbolos.count($1.label))
			yyerror("Erro: variável não declarada: " + $1.label);

		string tipo_var = tabela_simbolos[$1.label];
		if (tipo_var != $3.tipo)
			yyerror("Erro: Atribuição incompatível: variável " + $1.label + " é " + tipo_var + ", valor é " + $3.tipo);

		$$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
	}
	| TK_NUM
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = "int";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_FLOAT
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = "float";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_TRUE | TK_FALSE
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_ID
	{
		if (!tabela_simbolos.count($1.label))
			yyerror("Erro: variável não declarada: " + $1.label);

		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = tabela_simbolos[$1.label];
		declaracoes_temp[$$.label] = $$.tipo;
	}
	;

%%

#include "lex.yy.c"

string gentempcode()
{
	return "t" + to_string(++var_temp_qnt);
}

int yyparse();

int main(int argc, char* argv[])
{
	var_temp_qnt = 0;
	tabela_simbolos.clear();
	declaracoes_temp.clear();
	yyparse();
	return 0;
}

void yyerror(string MSG)
{
	cout << "Erro na linha " << contador_linha << ": " << MSG << endl;
	exit(1);
}
