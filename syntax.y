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
atributos converter_implicitamente(atributos op, string tipo_destino);
%}

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
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
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '+'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = $1.tipo;
		declaracoes_temp[$$.label] = $$.tipo;
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " + " + $3.label + ";\n";
	}
	| E '-' E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '-'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = $1.tipo;
		declaracoes_temp[$$.label] = $$.tipo;
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " - " + $3.label + ";\n";
	}
	| E '*' E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '*'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = $1.tipo;
		declaracoes_temp[$$.label] = $$.tipo;
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " * " + $3.label + ";\n";
	}
	| E '/' E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '/'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = $1.tipo;
		declaracoes_temp[$$.label] = $$.tipo;
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " / " + $3.label + ";\n";
	}
	| E '<' E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '<'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " < " + $3.label + ";\n";
	}
	| E '>' E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '>'");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " > " + $3.label + ";\n";
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
	| E TK_MAIOR_IGUAL E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '>='");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " >= " + $3.label + ";\n";
	}
	| E TK_MENOR_IGUAL E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '<='");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " <= " + $3.label + ";\n";
	}
	| E TK_DIFERENTE E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '!='");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " != " + $3.label + ";\n";
	}
	| E TK_IGUAL_IGUAL E
	{
		if ($1.tipo != $3.tipo) {
			if (($1.tipo == "int" && $3.tipo == "float") || ($1.tipo == "float" && $3.tipo == "int")) {
				$1 = converter_implicitamente($1, "float");
				$3 = converter_implicitamente($3, "float");
			} else {
				yyerror("Erro: tipos incompatíveis em '=='");
			}
		}
		$$.label = gentempcode();
		$$.tipo = "bool";
		declaracoes_temp[$$.label] = "int";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " == " + $3.label + ";\n";
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

		if (simb.tipo == "boolean" && $3.tipo == "int") {
			$$.traducao = $3.traducao + "\t" + simb.label + " = " + $3.label + ";\n";
			$$.label = simb.label;
			$$.tipo = simb.tipo;
		}
		
		else if ((simb.tipo == "int" && $3.tipo == "float") || (simb.tipo == "float" && $3.tipo == "int")) {
			atributos convertido = converter_implicitamente($3, simb.tipo);
			$$.traducao = convertido.traducao + "\t" + simb.label + " = " + convertido.label + ";\n";
			$$.label = simb.label;
			$$.tipo = simb.tipo;
		}

		else if (simb.tipo == $3.tipo) {
			$$.traducao = $3.traducao + "\t" + simb.label + " = " + $3.label + ";\n";
			$$.label = simb.label;
			$$.tipo = simb.tipo;
		}
		
		else {
			yyerror("Erro: tipos incompatíveis na atribuição");
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = $$.tipo;
	} 
	| TK_FALSE
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

		atributos simb = tabela_simbolos[$1.label];
		$$.label = simb.label;
		$$.traducao = "";
		$$.tipo = simb.tipo;
	}
	| '(' TIPO ')' E
	{
		string origem = $4.tipo;
		string destino = $2.tipo;

		bool conversaoPermitida = 
			(origem == "int" && destino == "float") ||
			(origem == "float" && destino == "int");

		if (!conversaoPermitida && origem != destino) {
			yyerror("Conversão entre tipos incompatíveis");
		}

		if (origem == destino) {
			$$ = $4;
		} else {
			$$.label = gentempcode();
			$$.tipo = destino;
			declaracoes_temp[$$.label] = destino;
			$$.traducao = $4.traducao + "\t" + $$.label + " = (" + destino + ") " + $4.label + ";\n";
		}
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

atributos converter_implicitamente(atributos op, string tipo_destino) {
	if (op.tipo == tipo_destino) return op;

	if ((op.tipo == "int" && tipo_destino == "float") || (op.tipo == "float" && tipo_destino == "int")) {
		atributos convertido;
		convertido.label = gentempcode();
		convertido.tipo = tipo_destino;
		convertido.traducao = op.traducao + "\t" + convertido.label + " = (" + tipo_destino + ") " + op.label + ";\n";
		declaracoes_temp[convertido.label] = tipo_destino;
		return convertido;
	}

	yyerror(("Conversão implícita inválida entre tipos '" + op.tipo + "' e '" + tipo_destino + "'").c_str());
	exit(1);
}