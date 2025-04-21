%{
#include <iostream>
#include <string>
#include <map>
#include <vector>

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

map<string, atributos> tabela_simbolos;
vector<string> ordem_declaracoes;
map<string, string> declaracoes_temp;

int yylex(void);
void yyerror(string);
string gentempcode();
%}

%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR
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

		for (auto &nome : ordem_declaracoes) {
			string tipo = declaracoes_temp[nome];
			if (tipo == "int") {
				codigo += "\tint " + nome + ";\n";
			} else if (tipo == "float") {
				codigo += "\tfloat " + nome + ";\n";
			} else if (tipo == "char") {
				codigo += "\tchar " + nome + ";\n";
			} else if (tipo == "boolean") {
				codigo += "\tint " + nome + ";\n";
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

		atributos simb;
		simb.label = gentempcode();
		simb.tipo = $1.tipo;

		tabela_simbolos[$2.label] = simb;
		declaracoes_temp[simb.label] = simb.tipo;
	}

	;

TIPO : TK_TIPO_INT    { $$.tipo = "int"; }
	 | TK_TIPO_FLOAT  { $$.tipo = "float"; }
	 | TK_TIPO_BOOL   { $$.tipo = "boolean"; }
	 | TK_TIPO_CHAR   { $$.tipo = "char"; }
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
	| E '<' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '<'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " < " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '>' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '>'");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " > " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '&' E
	{
		if ($1.tipo != "boolean" || $3.tipo != "boolean")
			yyerror("Erro: burro tem que ser booleano");
		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " && " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '|' E
	{
		if ($1.tipo != "boolean" || $3.tipo != "boolean")
			yyerror("Erro: burro tem que ser booleano");
		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " || " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| '~'E 
	{
		if ($2.tipo != "boolean")
			yyerror("Erro: burro tem que ser booleano");
		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $2.tipo;
		$$.traducao = $2.traducao +
			"\t" + $$.label + " = !" + $2.label + ";\n";
		$$.tipo = "boolean";	
	}
	| E '>''=' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '>='");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " >= " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '<''=' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '<='");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " <= " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '!''=' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '!='");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " != " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| E '=''=' E
	{
		if ($1.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis em '=='");

		$$.label = gentempcode();
		declaracoes_temp[$$.label] = $1.tipo;
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " == " + $3.label + ";\n";
		$$.tipo = "boolean";
	}
	| '(' E ')'
	{
		$$ = $2;
	}
	| TK_ID '=' E
	{
		if (!tabela_simbolos.count($1.label))
			yyerror("Erro: variável não declarada: " + $1.label);

		atributos simb = tabela_simbolos[$1.label];
		if(simb.tipo == "boolean" && $3.tipo == "int"){
			$$.traducao = $3.traducao + "\t" + simb.label + " = " + $3.label + ";\n";
			$$.label = simb.label;
			$$.tipo = simb.tipo;
		}else{
			if (simb.tipo != $3.tipo)
			yyerror("Erro: tipos incompatíveis na atribuição");

			$$.traducao = $3.traducao + "\t" + simb.label + " = " + $3.label + ";\n";
			$$.label = simb.label;
			$$.tipo = simb.tipo;
		}
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
	| TK_CHAR
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = "char";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_TRUE
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		declaracoes_temp[$$.label] = $$.tipo;
	} 
	| TK_FALSE
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_ID
	{
		if (!tabela_simbolos.count($1.label))
			yyerror("Erro: variável não declarada: " + $1.label);

		atributos simb = tabela_simbolos[$1.label];
		$$.label = simb.label;
		$$.traducao = "";
		$$.tipo = simb.tipo;
	}

	;

%%

#include "lex.yy.c"

string gentempcode()
{
	string nome = "t" + to_string(++var_temp_qnt);
    ordem_declaracoes.push_back(nome);
    return nome;
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
