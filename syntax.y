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
vector<pair<string, string>> pilha_loops;


static const map<string, string> mapa_tipos_linguagem_para_c = {
		{"int", "int"},
		{"float", "float"},
		{"char", "char"},
		{"boolean", "int"},
		{"string", "char*"}
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

atributos criar_expressao_unaria(atributos op, string op_str_lexical) {
	atributos res;
	if (op.tipo != "boolean" || op_str_lexical != "~") {
		if (op.tipo == "int" || op.tipo == "float") {
			res.label = op.label;
			res.tipo = op.tipo; // mantém o tipo original
			declaracoes_temp[res.label] = res.tipo;
			res.traducao = op.traducao + "\t" + res.label + " = " + op.label + " " + op_str_lexical + " 1;\n";
			return res;
		} else {
			yyerror("Erro: Operador unário '" + op_str_lexical + "' só pode ser aplicado a tipos numéricos.");
		}
	} else if (op.tipo!= "boolean" && op_str_lexical == "~") {
		yyerror("Erro: Operador unário '~' só pode ser aplicado a tipos booleanos.");
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
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR TK_STRING
%token TK_MAIN TK_IF TK_ELSE TK_WHILE TK_FOR TK_DO TK_SWITCH TK_PRINT TK_BREAK TK_CONTINUE
%token TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL TK_TIPO_STRING TK_ID TK_MAIS_MAIS TK_MENOS_MENOS
%token TK_FIM TK_ERROR

%start RAIZ
%right CAST
%right '='
%left '|' 
%left '&'
%left TK_IGUAL_IGUAL TK_DIFERENTE
%left '<' '>' TK_MENOR_IGUAL TK_MAIOR_IGUAL
%left '+' '-'
%left '*' '/'
%right '~'
%right TK_MAIS_MAIS TK_MENOS_MENOS 
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
	|  %empty { $$.traducao = ""; }
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
		codigo += "\treturn 0;\n}\n";
		$$.traducao = codigo;
		ordem_declaracoes.clear();
		declaracoes_temp.clear();
	}

BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
	{
		sair_escopo();
		$$.traducao = $3.traducao;
	}
	;

COMANDOS : COMANDO COMANDOS
	{ $$.traducao = $1.traducao + $2.traducao; }
	| 
	 %empty { 
		$$.traducao = ""; 
	}
	;

COMANDO : COD ';' { $$ = $1; }
	| TK_PRINT '(' E ')' ';'
	{
		$$.traducao = $3.traducao + "\tcout << " + $3.label + ";\n";
	}
	| TK_BREAK ';'
	{
		if (pilha_loops.empty()) {
			yyerror("Erro: 'brk' fora de um loop.");
			$$ = atributos();
		} else {
			string label_fim_loop = pilha_loops.back().first;
			$$.traducao = "\tgoto " + label_fim_loop + ";\n";
		}
	}
	|TK_CONTINUE ';'
	{
		if (pilha_loops.empty()) {
			yyerror("Erro: 'cnt' fora de um loop.");
			$$ = atributos();
		} else {
			string label_inicio_loop = pilha_loops.back().second;
			$$.traducao = "\tgoto " + label_inicio_loop + ";\n";
		}
	}
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
	| TK_WHILE '(' ')' { yyerror("Erro: Condição vazia em 'whl'."); $$ = atributos(); }
	| TK_WHILE '(' E ')'  //Na realidade fica, TK_WHILE '(' E ')' { /* Ação Intermediária */ } BLOCO
      { //Ação Intermediária
        string temp_loop_start = genlabel(); 
        string temp_loop_end = genlabel();   
        pilha_loops.push_back(make_pair(temp_loop_end, temp_loop_start));

        $$ = $3; 
      }
      BLOCO 
      { 
        pair<string, string> current_loop_labels = pilha_loops.back();
        string label_fim_while = current_loop_labels.first;
        string label_inicio_while = current_loop_labels.second;

		$$.traducao = label_inicio_while + ":\n";                // Marca o início do loop while
		$$.traducao += $5.traducao;                              // Código da condição do while
		$$.traducao += "\tif (!" + $5.label + "){\n";            // Se a condição for falsa
		$$.traducao += "\t\tgoto " + label_fim_while + ";\n";    // Sai do loop (goto para o fim)
		$$.traducao += "\t}\n";                                  // Fim do bloco if
		$$.traducao += $6.traducao;                              // Código do corpo do loop
		$$.traducao += "\tgoto " + label_inicio_while + ";\n";   // Volta para o início do loop
		$$.traducao += label_fim_while + ":\n";                  // Marca o fim do loop while

        pilha_loops.pop_back();
      }
	| TK_DO M_DO_SETUP BLOCO TK_WHILE '(' E ')' ';'
    {
        string label_inicio_bloco = $2.label;     // Rótulo de continue (início do bloco), vindo de M_DO_SETUP
        string label_fim_loop   = $2.traducao;  // Rótulo de break, vindo de M_DO_SETUP

        $$.traducao = label_inicio_bloco + ":\n";       // Início do bloco
        $$.traducao += $3.traducao;                     // Código do BLOCO
                                                        // O 'continue' dentro do BLOCO pularia para label_inicio_bloco
        $$.traducao += $6.traducao;                     // Código da expressão da condição E
        $$.traducao += "\tif (" + $6.label + "){\n";
        $$.traducao += "\t\tgoto " + label_inicio_bloco + ";\n"; // Se verdadeiro, volta ao início do BLOCO
        $$.traducao += "\t}\n";
        $$.traducao += label_fim_loop + ":\n";          // Rótulo de saída do loop (para onde o 'break' pularia)

        pilha_loops.pop_back(); // Remove os rótulos da pilha
    }
	| TK_FOR { entrar_escopo(); } '(' COD ';' E ';' // COD ($4), E-cond ($6)
      { 
        string temp_loop_continue = genlabel(); 
        string temp_loop_break = genlabel();    
        pilha_loops.push_back(make_pair(temp_loop_break, temp_loop_continue));

        $$ = $6; 
      }
      E ')' BLOCO 
      { 

        pair<string, string> current_loop_labels = pilha_loops.back();
        string label_fim_for = current_loop_labels.first;
        string label_continue_for = current_loop_labels.second;

        string label_condicao_for = genlabel(); 

        $$.traducao = $4.traducao;

        $$.traducao += label_condicao_for + ":\n";         
        $$.traducao += $8.traducao;                        
        $$.traducao += "\tif (!" + $8.label + "){\n";      
        $$.traducao += "\t\tgoto " + label_fim_for + ";\n"; 
        $$.traducao += "\t}\n";                            
        

        $$.traducao += $11.traducao;                       
        $$.traducao += label_continue_for + ":\n";         
        $$.traducao += $9.traducao;                        
        $$.traducao += "\tgoto " + label_condicao_for + ";\n"; 
        $$.traducao += label_fim_for + ":\n";              

        pilha_loops.pop_back();
        sair_escopo();
      }
	| BLOCO
	{
		$$.traducao = $1.traducao;
	}
	;
M_DO_SETUP : %empty
    {
        string continue_label = genlabel(); // Será o rótulo para o início do bloco do DO
        string break_label = genlabel();    // Será o rótulo para o qual o BREAK desviará

        // Empilha: o primeiro é o rótulo de break, o segundo é o de continue
        pilha_loops.push_back(make_pair(break_label, continue_label));

        // Passa os rótulos para a regra principal do DO-WHILE
        // Usando $$.label para continue_label e $$.traducao para break_label
        $$.label = continue_label;
        $$.traducao = break_label;
        $$.tipo = "do_loop_setup_labels"; // Tipo opcional para depuração
    }
    ;
COD : DECLARACAO 
	{
		$$.traducao = $1.traducao;
	}
	| E 
	{
		$$.traducao = $1.traducao;
	}
	;
DECLARACAO : TIPO TK_ID 
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
	| TIPO TK_ID '=' E 
	{
		string original_name = $2.label;
		string c_code_name = gentempcode();
		string tipo_declarado = $1.tipo; 
		atributos expressao_rhs = $4;
		atributos valor_para_atribuir = expressao_rhs;

		$$.label = c_code_name;
		$$.tipo = tipo_declarado;
		$$.traducao = ""; 

		if (declarar_simbolo(original_name, tipo_declarado, c_code_name)) {
				declaracoes_temp[c_code_name] = tipo_declarado;
				mapa_c_para_original[c_code_name] = original_name;
				if (tipo_declarado != expressao_rhs.tipo) {    
						if ((tipo_declarado == "float" && expressao_rhs.tipo == "int") ||
								(tipo_declarado == "int" && expressao_rhs.tipo == "float")) {
								valor_para_atribuir = converter_implicitamente(expressao_rhs, tipo_declarado);
						} else {
								yyerror("Erro Semantico: tipo incompatível na atribuição da declaração de '" + original_name + "'. Esperado '" + tipo_declarado + "', recebido '" + expressao_rhs.tipo + "'.");
						}
				} 
				$$.traducao = valor_para_atribuir.traducao; 
				$$.traducao += "\t" + c_code_name + " = " + valor_para_atribuir.label + ";\n";
			}
	};

TIPO : TK_TIPO_INT { $$.tipo = "int"; }
	| TK_TIPO_FLOAT { $$.tipo = "float"; }
	| TK_TIPO_BOOL { $$.tipo = "boolean"; }
	| TK_TIPO_CHAR { $$.tipo = "char"; }
	| TK_TIPO_STRING { $$.tipo = "string"; }
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
	{ $$ = criar_expressao_unaria($2, "~"); }	
	| E TK_MENOS_MENOS
	{ $$ = criar_expressao_unaria($1, "-"); }
	| E TK_MAIS_MAIS
	{ $$ = criar_expressao_unaria($1, "+"); }
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
	| TK_STRING
	{
		$$.label = gentempcode();
		$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
		$$.tipo = "string";
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
	| '(' TIPO ')' E %prec CAST
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