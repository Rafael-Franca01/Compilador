%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>

#define YYSTYPE atributos

using namespace std;
int goto_label_qnt = 0;
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
map<string, string> mapa_c_para_original;

static const map<string, string> mapa_tipos_linguagem_para_c = {
		{"int", "int"},
		{"float", "float"},
		{"char", "char"},
		{"boolean", "int"}
};
 
int yylex(void);
void yyerror(string);
string gentempcode();

string genlabel(){
	return "G" + to_string(++goto_label_qnt);
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

string gerar_codigo_declaracoes(
	const vector<string>& p_ordem_declaracoes, 
	const map<string, string>& p_declaracoes_temp, 
	const map<string, string>& p_mapa_c_para_original
	) {	
    string codigo_local;
    for (const auto &c_name : p_ordem_declaracoes) {
        auto it_decl_type = p_declaracoes_temp.find(c_name);
        if (it_decl_type != p_declaracoes_temp.end()) {
            const string& tipo_linguagem = it_decl_type->second;

            string tipo_c_str = tipo_linguagem; // Valor padrão
            auto it_mapa_tipos = mapa_tipos_linguagem_para_c.find(tipo_linguagem);
            if (it_mapa_tipos != mapa_tipos_linguagem_para_c.end()) {
                tipo_c_str = it_mapa_tipos->second;
            }

            codigo_local += "\t" + tipo_c_str + " " + c_name + ";";

            auto it_orig_name = p_mapa_c_para_original.find(c_name);
            if (it_orig_name != p_mapa_c_para_original.end()) {
                codigo_local += " // " + it_orig_name->second; // Adiciona o comentário
            }
            codigo_local += "\n";
        }
    }
    return codigo_local;
}

atributos criar_expressao_binaria(atributos op1, string op_str_lexical, string op_str_c, atributos op2) {
    atributos res;
    string tipo_final_operacao = "error"; // se der merda ele nao foi mudado

		// define os tipos na função e virifica quais são
    bool eh_comparacao = (op_str_c == "<" || op_str_c == ">" || op_str_c == "<=" || op_str_c == ">=" || op_str_c == "==" || op_str_c == "!=");
    bool eh_logico_e_ou = (op_str_lexical == "&" || op_str_lexical == "|"); 

    // se ele ~NAO~ for logico entra aqui e faz conversão implicita se necessaria
    if (!eh_logico_e_ou) {
        if (op1.tipo != op2.tipo) {
            if ((op1.tipo == "int" && op2.tipo == "float") || (op1.tipo == "float" && op2.tipo == "int")) {
                op1 = converter_implicitamente(op1, "float"); 
                op2 = converter_implicitamente(op2, "float");
                tipo_final_operacao = "float";
            } else {
                yyerror("Erro: tipos incompatíveis '" + op1.tipo + "' e '" + op2.tipo + "' para operador '" + op_str_lexical + "'");
                res.tipo = "error";
                return res;
            }
        } else { //se os tipos forem iguais define o tipo da operação
            tipo_final_operacao = op1.tipo; 
        }
    }

    // se for operador logico entra aqui
    if (eh_logico_e_ou) {
        if (op1.tipo != "boolean" || op2.tipo != "boolean") {
            yyerror("Erro: operandos para '" + op_str_lexical + "' devem ser booleanos.");
            res.tipo = "error";
            return res;
        }
        tipo_final_operacao = "boolean";
    }

    
    if (eh_comparacao || eh_logico_e_ou) {
        res.tipo = "boolean";
    } else { 
        res.tipo = tipo_final_operacao;
    }

    // gera o codigo da operação
    res.label = gentempcode();
    declaracoes_temp[res.label] = res.tipo; 
    res.traducao = op1.traducao + op2.traducao +
                   "\t" + res.label + " = " + op1.label + " " + op_str_c + " " + op2.label + ";\n";
    return res;
}

atributos criar_expressao_unaria_not(atributos op) {
    atributos res;
    if (op.tipo != "boolean") {
        yyerror("Erro: operando de '~' (NOT logico) deve ser booleano");
        res.tipo = "error";
        return res;
    }
    res.label = gentempcode();
    res.tipo = "boolean";
    declaracoes_temp[res.label] = res.tipo;
    res.traducao = op.traducao + "\t" + res.label + " = !" + op.label + ";\n";
    return res;
}

%}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR
%token TK_MAIN TK_IF TK_ELSE TK_WHILE
%token TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL TK_ID
%token TK_FIM TK_ERROR

%start RAIZ

%left '+' '-'
%left '*' '/'

%%

RAIZ : SEXO 
	{
		string includes = "/Compilador PCD/\n"
                      "#include <iostream>\n"
                      "#include <string.h>\n" 
                      "#include <stdio.h>\n\n"; 
    cout << includes << $1.traducao << endl;
	}

SEXO : S SEXO
	{ $$.traducao = $1.traducao + $2.traducao; }
	| { $$.traducao = ""; }
	;

S : COMANDO
	{
		string codigo;
		codigo += gerar_codigo_declaracoes(ordem_declaracoes, declaracoes_temp, mapa_c_para_original);
		codigo += $1.traducao;
		$$.traducao = codigo;
		ordem_declaracoes.clear();
		declaracoes_temp.clear();
	}
| TK_TIPO_INT TK_MAIN '(' ')' BLOCO
	{
		string codigo;
		codigo += "int main(void) {\n";
		codigo += gerar_codigo_declaracoes(ordem_declaracoes, declaracoes_temp, mapa_c_para_original);
		codigo += "\n";
		codigo += $5.traducao;
		codigo += "\treturn 0;\n}";
		$$.traducao = codigo;
		ordem_declaracoes.clear();
		declaracoes_temp.clear();
	}

BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
	{
		sair_escopo();
		$$.traducao = $3.traducao;
	}
	/* | COMANDO
	{
		$$.traducao = $1.traducao;
	} */
	;

COMANDOS : COMANDO COMANDOS
	{ $$.traducao = $1.traducao + $2.traducao; }
	| { $$.traducao = ""; }
	;

COMANDO : DECLARACAO { $$ = $1; }
	| E ';' { $$ = $1; }
	| TK_IF '(' ')' { yyerror("Erro: Condição vazia em 'if'."); $$ = atributos(); }
	| TK_IF '(' E ')' BLOCO
	{
		string label_fim = genlabel();
		$$.traducao = $3.traducao; 
    $$.traducao += "\tif (!" + $3.label + "){\n";
		$$.traducao += "\t\tgoto " + label_fim + ";\n";
		$$.traducao += "\t}\n";
    $$.traducao += $5.traducao; 
    $$.traducao += label_fim + ":\n";       
	} 
	| TK_IF '(' E ')' BLOCO TK_ELSE BLOCO
	{
		string label_fim = genlabel();
		string label_else = genlabel();
		$$.traducao = $3.traducao; 
		$$.traducao += "\tif (!" + $3.label + "){\n";
		$$.traducao += "\t\tgoto " + label_else + ";\n";
		$$.traducao += "\t}\n";
		$$.traducao += $5.traducao; 
		$$.traducao += "\tgoto " + label_fim + ";\n";
		$$.traducao += label_else + ":\n"; 
		$$.traducao += $7.traducao; 
		$$.traducao += label_fim + ":\n";       
	}
	| TK_WHILE '(' ')' { yyerror("Erro: Condição vazia em 'if'."); $$ = atributos(); }
	| TK_WHILE '(' E ')' BLOCO
    {
        string label_inicio_while = genlabel(); // Ex: G1
        string label_fim_while = genlabel();    // Ex: G2

        $$.traducao = label_inicio_while + ":\n";           // G1:
        $$.traducao += $3.traducao;                         //   código da expressão (condição)
                                                            //   (ex: t1 = a < 10;)
        $$.traducao += "\tif (!" + $3.label + "){\n";       //   if (!t1) {
        $$.traducao += "\t\tgoto " + label_fim_while + ";\n"; //     goto G2;
        $$.traducao += "\t}\n";                             //   }
        $$.traducao += $5.traducao;                         //   código do bloco do while
        $$.traducao += "\tgoto " + label_inicio_while + ";\n"; //   goto G1;
        $$.traducao += label_fim_while + ":\n";             // G2:
    }
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
			mapa_c_para_original[c_code_name] = original_name;
		}
	}
	;

TIPO : TK_TIPO_INT { $$.tipo = "int"; }
	| TK_TIPO_FLOAT { $$.tipo = "float"; }
	| TK_TIPO_BOOL { $$.tipo = "boolean"; }
	| TK_TIPO_CHAR { $$.tipo = "char"; }
	;

E : E '+' E
	{ $$ = criar_expressao_binaria($1, "+", "+", $3); }
	| E '-' E
	{ $$ = criar_expressao_binaria($1, "-", "-", $3); }
	| E '*' E
	{ $$ = criar_expressao_binaria($1, "*", "*", $3); }
	| E '/' E
	{ $$ = criar_expressao_binaria($1, "/", "/", $3); }
	| E '<' E
	{ $$ = criar_expressao_binaria($1, "<", "<", $3); }
	| E '>' E
	{ $$ = criar_expressao_binaria($1, ">", ">", $3); }
	| E '&' E
	{ $$ = criar_expressao_binaria($1, "&", "&&", $3); }
	| E '|' E
	{ $$ = criar_expressao_binaria($1, "|", "||", $3); }
	| '~' E
	{ $$ = criar_expressao_unaria_not($2); }
	| E TK_MAIOR_IGUAL E
	{ $$ = criar_expressao_binaria($1, ">=", ">=", $3); }
	| E TK_MENOR_IGUAL E
	{ $$ = criar_expressao_binaria($1, "<=", "<=", $3); }
	| E TK_DIFERENTE E
	{ $$ = criar_expressao_binaria($1, "!=", "!=", $3); }
	| E TK_IGUAL_IGUAL E
	{ $$ = criar_expressao_binaria($1, "==", "==", $3); }
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

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	mapa_c_para_original.clear();
	yyparse();
	sair_escopo();
	return 0;
}

void yyerror(string MSG)
{
	cout << "Erro na linha " << contador_linha << ": " << MSG << endl;
	exit(1);
}