%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>

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

vector<map<string, atributos>> pilha_tabelas_simbolos;
vector<string> ordem_declaracoes;
map<string, string> declaracoes_temp;

int yylex(void);
void yyerror(string);
string gentempcode();

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

bool declarar_simbolo(const string& nome_original, const string& tipo_var, const string& label_unico_c) {
	if (pilha_tabelas_simbolos.empty()) {
		yyerror("Erro crítico: Tentativa de declarar símbolo '" + nome_original + "' com pilha de escopos vazia.");
		return false;
	}
	map<string, atributos>& escopo_atual = pilha_tabelas_simbolos.back();
	if (escopo_atual.count(nome_original)) {
		yyerror(("Erro Semantico: Variavel '" + nome_original + "' ja declarada neste escopo.").c_str());
		return false;
	}
	atributos atrib;
	atrib.label = label_unico_c;
	atrib.tipo = tipo_var;
	atrib.traducao = "";
	escopo_atual[nome_original] = atrib;
	return true;
}

atributos* buscar_simbolo(const string& nome_original) {
	if (pilha_tabelas_simbolos.empty()) {
		return nullptr;
	}
	for (auto it = pilha_tabelas_simbolos.rbegin(); it != pilha_tabelas_simbolos.rend(); ++it) {
		map<string, atributos>& escopo_atual = *it;
		if (escopo_atual.count(nome_original)) {
			return &escopo_atual[nome_original];
		}
	}
	return nullptr;
}

void entrar_escopo() {
	pilha_tabelas_simbolos.emplace_back();
}

void sair_escopo() {
	if (!pilha_tabelas_simbolos.empty()) {
		pilha_tabelas_simbolos.pop_back();
	} else {
		cerr << "Erro crítico: Tentativa de sair de escopo com pilha vazia!" << endl;
	}
}
%}

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR
%token TK_MAIN TK_ID TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL
%token TK_FIM TK_ERROR

%start SEXO

%left '+' '-'
%left '*' '/'

%%

SEXO : S SEXO
	{ $$.traducao = $1.traducao + $2.traducao; }
	| { $$.traducao = ""; }
	;

S : TK_TIPO_INT TK_MAIN '(' ')' BLOCO
	{
		string codigo = "/Compilador PCD/\n"
						"#include <iostream>\n"
						"#include<string.h>\n"
						"#include<stdio.h>\n";
		codigo +=			"int main(void) {\n";


		for (const auto &nome : ordem_declaracoes) {
			if (declaracoes_temp.count(nome)) {
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
		}

		codigo += "\n";
		codigo += $5.traducao;
		codigo += "\treturn 0;\n}";

		cout << codigo << endl;

		ordem_declaracoes.clear();
		declaracoes_temp.clear();
	}
	| BLOCO
	{
		string codigo;
		for (const auto &nome : ordem_declaracoes) {
			if (declaracoes_temp.count(nome)) {
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
		}

		codigo += "\n";
		codigo += $1.traducao;

		cout << codigo << endl;

		ordem_declaracoes.clear();
		declaracoes_temp.clear();
	}
	;

BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
	{
		sair_escopo();
		$$.traducao = $3.traducao;
	}
	;

COMANDOS : COMANDO COMANDOS
	{ $$.traducao = $1.traducao + $2.traducao; }
	| { $$.traducao = ""; }
	;

COMANDO : DECLARACAO { $$ = $1; }
	| E ';' { $$ = $1; }
	| BLOCO { $$ = $1; }
	;

DECLARACAO : TIPO TK_ID ';'
	{
		string original_name = $2.label;
		string c_code_name = gentempcode();

		$$.label = c_code_name;
		$$.tipo = $1.tipo;
		$$.traducao = "";

		if (declarar_simbolo(original_name, $1.tipo, c_code_name)) {
			declaracoes_temp[c_code_name] = $1.tipo;
		}
	}
	;

TIPO : TK_TIPO_INT { $$.tipo = "int"; }
	| TK_TIPO_FLOAT { $$.tipo = "float"; }
	| TK_TIPO_BOOL { $$.tipo = "boolean"; }
	| TK_TIPO_CHAR { $$.tipo = "char"; }
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " > " + $3.label + ";\n";
	}
	| E '&' E
	{
		if ($1.tipo != "boolean" || $3.tipo != "boolean")
			yyerror("Erro: operandos de '&' (AND logico) devem ser booleanos");
		$$.label = gentempcode();
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " && " + $3.label + ";\n";
	}
	| E '|' E
	{
		if ($1.tipo != "boolean" || $3.tipo != "boolean")
			yyerror("Erro: operandos de '|' (OR logico) devem ser booleanos");
		$$.label = gentempcode();
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
		$$.traducao = $1.traducao + $3.traducao +
			"\t" + $$.label + " = " + $1.label + " || " + $3.label + ";\n";
	}
	| '~' E
	{
		if ($2.tipo != "boolean")
			yyerror("Erro: operando de '~' (NOT logico) deve ser booleano");
		$$.label = gentempcode();
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
		$$.traducao = $2.traducao +
			"\t" + $$.label + " = !" + $2.label + ";\n";
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
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
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = "boolean";
		$$.traducao = $1.traducao + $3.traducao +
					"\t" + $$.label + " = " + $1.label + " == " + $3.label + ";\n";
	}
	| '(' E ')'
	{
		$$ = $2;
	}
	| TK_ID '=' E
	{
		atributos* simb_ptr = buscar_simbolo($1.label);
		if (!simb_ptr) {
			yyerror("Erro Semantico: variavel '" + $1.label + "' nao declarada.");
			$$.label = ""; $$.tipo = "error"; $$.traducao = "";
		} else {
			atributos simb = *simb_ptr;
			atributos rhs = $3;

			if (simb.tipo == "boolean" && (rhs.tipo == "int" || rhs.tipo == "boolean")) {
				$$.traducao = rhs.traducao + "\t" + simb.label + " = " + rhs.label + ";\n";
				$$.label = simb.label;
				$$.tipo = simb.tipo;
			}
			else if ((simb.tipo == "int" && rhs.tipo == "float") || (simb.tipo == "float" && rhs.tipo == "int")) {
				atributos convertido = converter_implicitamente(rhs, simb.tipo);
				$$.traducao = convertido.traducao + "\t" + simb.label + " = " + convertido.label + ";\n";
				$$.label = simb.label;
				$$.tipo = simb.tipo;
			}
			else if (simb.tipo == rhs.tipo) {
				$$.traducao = rhs.traducao + "\t" + simb.label + " = " + rhs.label + ";\n";
				$$.label = simb.label;
				$$.tipo = simb.tipo;
			}
			else {
				yyerror("Erro Semantico: tipos incompatíveis na atribuicao para '" + simb.label + "'. Esperado '" + simb.tipo + "', recebido '" + rhs.tipo + "'.");
				$$.label = ""; $$.tipo = "error"; $$.traducao = "";
			}
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
		$$.traducao = "\t" + $$.label + " = 1;\n";
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_FALSE
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = 0;\n";
		$$.tipo = "boolean";
		declaracoes_temp[$$.label] = $$.tipo;
	}
	| TK_ID
	{
		atributos* simb_ptr = buscar_simbolo($1.label);
		if (!simb_ptr) {
			yyerror("Erro Semantico: variavel '" + $1.label + "' nao declarada.");
			$$.label = $1.label;
			$$.traducao = "";
			$$.tipo = "error";
		} else {
			$$.label = simb_ptr->label;
			$$.traducao = "";
			$$.tipo = simb_ptr->tipo;
		}
	}
	| '(' TIPO ')' E
	{
		string origem = $4.tipo;
		string destino = $2.tipo;

		bool conversaoPermitida =
			(origem == "int" && destino == "float") ||
			(origem == "float" && destino == "int") ||
			(origem == "int" && destino == "char") ||
			(origem == "char" && destino == "int") ||
			(origem == destino);

		if (!conversaoPermitida) {
			yyerror("Conversao explicita entre tipos incompatíveis: de '" + origem + "' para '" + destino + "'.");
			$$ = $4;
			$$.tipo = "error";
		} else if (origem == destino) {
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

int main(int argc, char* argv[])
{
	var_temp_qnt = 0;
	pilha_tabelas_simbolos.clear();
	entrar_escopo();
	declaracoes_temp.clear();
	ordem_declaracoes.clear();
	yyparse();
	sair_escopo();
	return 0;
}

void yyerror(string MSG)
{
	cout << "Erro na linha " << contador_linha << ": " << MSG << endl;
	exit(1);
}