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
string codigo_funcoes_auxiliares;
bool funcao_strlen_gerada = false;

struct atributos
{
	string label;
	string traducao;
	string tipo;
	int tamanho_string;
	bool literal = false;
};

vector<map<string, atributos>> pilha_tabelas_simbolos;
vector<string> ordem_declaracoes;
map<string, string> declaracoes_temp;
map<string, string> mapa_c_para_original;
vector<pair<string, string>> pilha_loops;

void gerar_funcao_strlen_se_necessario();
string contar_string();


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
			auto it_orig_name = p_mapa_c_para_original.find(c_name);
			if (it_decl_type != p_declaracoes_temp.end()) {
					const string& tipo_linguagem = it_decl_type->second;
					string tipo_c_str = ""; 

					// Lógica modificada para declaração de string
					if (tipo_linguagem == "string") {
						if(!(it_orig_name != p_mapa_c_para_original.end())){
							tipo_c_str = "char*";
							codigo_local += "\t" + tipo_c_str + " " + c_name + ";";
						}else{
							tipo_c_str = "char*";
							codigo_local += "\t" + tipo_c_str + " " + c_name + " = NULL;";
						}
						
					} else {
							// Lógica para outros tipos permanece a mesma
							auto it_mapa_tipos = mapa_tipos_linguagem_para_c.find(tipo_linguagem);
							if (it_mapa_tipos != mapa_tipos_linguagem_para_c.end()) {
									tipo_c_str = it_mapa_tipos->second;
							}
							codigo_local += "\t" + tipo_c_str + " " + c_name + ";";
					}

					
					if (it_orig_name != p_mapa_c_para_original.end()) {
							codigo_local += " // " + it_orig_name->second;
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

void gerar_funcao_strlen_se_necessario() {
    if (funcao_strlen_gerada) return;

    string temp_tamanho = "t" + to_string(++var_temp_qnt);
    string temp_ponteiro = "t" + to_string(++var_temp_qnt);
    string temp_char_atual = "t" + to_string(++var_temp_qnt);
    string temp_condicao = "t" + to_string(++var_temp_qnt);
    
    string label_inicio = genlabel();
    string label_fim = genlabel();
    
    codigo_funcoes_auxiliares += "int obter_tamanho_string(char* string_entrada) {\n";
   
    codigo_funcoes_auxiliares += "\tint " + temp_tamanho + ";\n";
    codigo_funcoes_auxiliares += "\tchar* " + temp_ponteiro + ";\n";
    codigo_funcoes_auxiliares += "\tchar " + temp_char_atual + ";\n";
    codigo_funcoes_auxiliares += "\tint " + temp_condicao + ";\n\n";

    codigo_funcoes_auxiliares += "\t" + temp_tamanho + " = 0;\n";
    codigo_funcoes_auxiliares += "\t" + temp_ponteiro + " = string_entrada;\n";

    codigo_funcoes_auxiliares += "\t" + label_inicio + ":\n";
    codigo_funcoes_auxiliares += "\t\t" + temp_char_atual + " = *" + temp_ponteiro + ";\n";
    codigo_funcoes_auxiliares += "\t\t" + temp_condicao + " = " + temp_char_atual + " == 0;\n";
    codigo_funcoes_auxiliares += "\t\tif (" + temp_condicao + ") goto " + label_fim + ";\n";
    codigo_funcoes_auxiliares += "\t\t" + temp_tamanho + " = " + temp_tamanho + " + 1;\n";
    codigo_funcoes_auxiliares += "\t\t" + temp_ponteiro + " = " + temp_ponteiro + " + 1;\n";
    codigo_funcoes_auxiliares += "\t\tgoto " + label_inicio + ";\n";
    codigo_funcoes_auxiliares += "\t" + label_fim + ":\n";
    codigo_funcoes_auxiliares += "\treturn " + temp_tamanho + ";\n";
    codigo_funcoes_auxiliares += "}\n\n";

    funcao_strlen_gerada = true;
}

string contar_string(string ponteiro_destino_c_name, atributos string_origem_rhs) {
    gerar_funcao_strlen_se_necessario(); // Garante que a função auxiliar seja criada

    string len_temp = gentempcode();
    declaracoes_temp[len_temp] = "int";
    
	string tamanho_total_temp = gentempcode();
    declaracoes_temp[tamanho_total_temp] = "int";

    string codigo_gerado = string_origem_rhs.traducao;
    
    // Gera a chamada para a função auxiliar
    codigo_gerado += "\t" + len_temp + " = obter_tamanho_string(" + string_origem_rhs.label + ");\n";
    // Aloca memória com base no resultado
    codigo_gerado += "\t" + tamanho_total_temp + " = " + len_temp + " + 1;\n";
	codigo_gerado += "\t" + ponteiro_destino_c_name + " = (char*) malloc(" + tamanho_total_temp + ");\n";
    // Copia a string
    codigo_gerado += "\tstrcpy(" + ponteiro_destino_c_name + ", " + string_origem_rhs.label + ");\n";
    
    return codigo_gerado;
}

%}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR TK_STRING
%token TK_MAIN TK_IF TK_ELSE TK_WHILE TK_FOR TK_DO TK_SWITCH TK_PRINT TK_SCANF TK_BREAK TK_CONTINUE
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
											"#include <stdlib.h>\n"
                      "#include <stdio.h>\n\n"; 
    cout << includes << codigo_funcoes_auxiliares << $1.traducao << endl;
	}

SEXO : S SEXO
	{ $$.traducao = $1.traducao + $2.traducao; }
	|  { $$.traducao = ""; }
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
	{ 
		$$.traducao = ""; 
	}
	;

COMANDO : COD ';' { $$ = $1; }
	| TK_PRINT '(' E ')' ';'
	{
		$$.traducao = $3.traducao + "\tstd::cout << " + $3.label + ";\n";
	}
	| TK_SCANF '(' TK_ID ')' ';'
    {
        atributos* simb_ptr = buscar_simbolo($3.label);
        if (!simb_ptr) {
            yyerror("Erro Semantico: variavel '" + $3.label + "' nao declarada para receber.");
            $$ = atributos();
        } else {
            string c_var_name = simb_ptr->label;
            string var_tipo = simb_ptr->tipo;
            $$.traducao = "";

            if (var_tipo == "string") {
                string len_temp = gentempcode();
                string cap_temp = gentempcode();
                string char_in_temp = gentempcode();
                string scanf_ret_temp = gentempcode();
                string ptr_dest_temp = gentempcode();
                string cond_temp = gentempcode();
                string cap_limit_temp = gentempcode();
                string L_loop_start = genlabel();
                string L_fim_loop = genlabel();
                string L_skip_free = genlabel();
                string L_skip_realloc = genlabel();
                $$.traducao += "\t{\n";
                $$.traducao += "\t\tint " + len_temp + " = 0;\n";
                $$.traducao += "\t\tint " + cap_temp + " = 16;\n";
                $$.traducao += "\t\tchar " + char_in_temp + ";\n";
                $$.traducao += "\t\tint " + scanf_ret_temp + ";\n";
                $$.traducao += "\t\tchar* " + ptr_dest_temp + ";\n";
                $$.traducao += "\t\tint " + cond_temp + ";\n";
                $$.traducao += "\t\tint " + cap_limit_temp + ";\n";

                $$.traducao += "\t\t" + cond_temp + " = " + c_var_name + " != NULL;\n";
                $$.traducao += "\t\tif (" + cond_temp + ") goto " + L_skip_free + ";\n";
                $$.traducao += "\t\tfree(" + c_var_name + ");\n";
                $$.traducao += "\t\t" + L_skip_free + ":\n";
                
                $$.traducao += "\t\t" + c_var_name + " = (char*) malloc(" + cap_temp + ");\n";
                
                $$.traducao += "\t\t" + L_loop_start + ":\n";
                $$.traducao += "\t\t\t" + scanf_ret_temp + " = scanf(\"%c\", &" + char_in_temp + ");\n";
                
                $$.traducao += "\t\t\t" + cond_temp + " = " + scanf_ret_temp + " != 1;\n";
                $$.traducao += "\t\t\tif (" + cond_temp + ") goto " + L_fim_loop + ";\n";
                $$.traducao += "\t\t\t" + cond_temp + " = " + char_in_temp + " == '\\n';\n";
                $$.traducao += "\t\t\tif (" + cond_temp + ") goto " + L_fim_loop + ";\n";
                
                $$.traducao += "\t\t\t" + cap_limit_temp + " = " + cap_temp + " - 1;\n";
                $$.traducao += "\t\t\t" + cond_temp + " = " + len_temp + " >= " + cap_limit_temp + ";\n";
                $$.traducao += "\t\t\tif (!" + cond_temp + ") goto " + L_skip_realloc + ";\n";
                $$.traducao += "\t\t\t\t" + cap_temp + " = " + cap_temp + " * 2;\n";
                $$.traducao += "\t\t\t\t" + c_var_name + " = (char*) realloc(" + c_var_name + ", " + cap_temp + ");\n";
                $$.traducao += "\t\t\t" + L_skip_realloc + ":\n";
                
                $$.traducao += "\t\t\t" + ptr_dest_temp + " = " + c_var_name + " + " + len_temp + ";\n";
                $$.traducao += "\t\t\t*" + ptr_dest_temp + " = " + char_in_temp + ";\n";
                
                $$.traducao += "\t\t\t" + len_temp + " = " + len_temp + " + 1;\n";
                $$.traducao += "\t\t\tgoto " + L_loop_start + ";\n";
    
                $$.traducao += "\t\t" + L_fim_loop + ":\n";
                $$.traducao += "\t\t\t" + ptr_dest_temp + " = " + c_var_name + " + " + len_temp + ";\n";
                $$.traducao += "\t\t\t*" + ptr_dest_temp + " = '\\0';\n";
                $$.traducao += "\t}\n";

            } else {
                string format_specifier = "";
                if (var_tipo == "int" || var_tipo == "boolean") format_specifier = "%d";
                else if (var_tipo == "float") format_specifier = "%f";
                else if (var_tipo == "char") format_specifier = " %c"; 
                else yyerror("Erro: Tipo '" + var_tipo + "' inválido para leitura com 'leia'.");
                
                if (!format_specifier.empty()) {
                    $$.traducao += "\tscanf(\"" + format_specifier + "\", &" + c_var_name + ");\n";
                }
            }
            
            $$.label = "";
            $$.tipo = "statement";
        }
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
M_DO_SETUP : 
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
    $$.label = c_code_name; 
    $$.tipo = tipo_declarado;

    if (declarar_simbolo(original_name, tipo_declarado, c_code_name)) {
        declaracoes_temp[c_code_name] = tipo_declarado;
        mapa_c_para_original[c_code_name] = original_name;

        // --- INÍCIO DA LÓGICA ALTERADA ---
        if (tipo_declarado == "string" && $4.tipo == "string") {
            atributos rhs = $4; // Atributos do lado direito (Right-Hand Side)

            if (rhs.literal) { // Verifica a flag que indica se é um literal
                // Otimização: É um literal de string, usa o tamanho pré-calculado do Lexer.
                int tamanho_necessario = rhs.tamanho_string + 1;
                // A traducao de um literal deve ser vazia, mas incluímos por segurança.
                $$.traducao = rhs.traducao; 
                $$.traducao += "\t" + c_code_name + " = (char*) malloc(" + to_string(tamanho_necessario) + ");\n";
                $$.traducao += "\tstrcpy(" + c_code_name + ", " + rhs.label + ");\n";
            } else {
                // Não é um literal (ex: str a = b;), então o tamanho é desconhecido.
                // Usa a função auxiliar para copiar a string dinamicamente.
                $$.traducao = contar_string(c_code_name, rhs);
            }
        } else {
            // Lógica que você já tinha para os outros tipos (int, float, etc.)
            atributos valor_para_atribuir = $4;
            if (tipo_declarado != valor_para_atribuir.tipo) {
                if ((tipo_declarado == "float" && valor_para_atribuir.tipo == "int") ||
                    (tipo_declarado == "int" && valor_para_atribuir.tipo == "float")) {
                    valor_para_atribuir = converter_implicitamente(valor_para_atribuir, tipo_declarado);
                } else {
                    yyerror("Erro Semantico: tipo incompatível na atribuição da declaração de '" + original_name + "'. Esperado '" + tipo_declarado + "', recebido '" + valor_para_atribuir.tipo + "'.");
                }
            } 
            $$.traducao = valor_para_atribuir.traducao; 
            $$.traducao += "\t" + c_code_name + " = " + valor_para_atribuir.label + ";\n";
        }
        // --- FIM DA LÓGICA ALTERADA ---
    }
}
;

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
        atributos rhs = $3; // Atributos do lado direito (Right-Hand Side)

        // --- INÍCIO DA LÓGICA INTELIGENTE E SEM AMBIGUIDADE ---
        if (simb.tipo == "string" && rhs.tipo == "string") {
            if (rhs.literal) { // Verifica se o lado direito é um literal
                // SIM: Otimização para atribuição de literal de string
                string c_var_name = simb.label;
                int tamanho_necessario = rhs.tamanho_string + 1;
                
                // Libera a memória antiga (se houver) e aloca a nova
                $$.traducao = "\tfree(" + c_var_name + ");\n"; 
                $$.traducao += "\t" + c_var_name + " = (char*) malloc(" + to_string(tamanho_necessario) + ");\n";
                $$.traducao += "\tstrcpy(" + c_var_name + ", " + rhs.label + ");\n";
                
                $$.label = c_var_name;
                $$.tipo = simb.tipo;
            } else {
                // NÃO: Atribuição de uma variável string a outra, usa a função auxiliar
                $$.traducao = contar_string(simb.label, rhs);
                $$.label = simb.label;
                $$.tipo = simb.tipo;
            }
        }
        else if ((simb.tipo == "int" && rhs.tipo == "float") || (simb.tipo == "float" && rhs.tipo == "int")) {
            // Lógica de conversão implícita
            atributos convertido = converter_implicitamente(rhs, simb.tipo);
            $$.traducao = convertido.traducao + "\t" + simb.label + " = " + convertido.label + ";\n";
            $$.label = simb.label;
            $$.tipo = simb.tipo;
        }
        else if (simb.tipo == rhs.tipo || (simb.tipo == "boolean" && (rhs.tipo == "int" || rhs.tipo == "boolean"))) {
            // Lógica de atribuição direta para tipos compatíveis
            $$.traducao = rhs.traducao + "\t" + simb.label + " = " + rhs.label + ";\n";
            $$.label = simb.label;
            $$.tipo = simb.tipo;
        }
        else {
            // Erro de tipos incompatíveis
            yyerror("Erro Semantico: tipos incompatíveis na atribuicao para '" + $1.label + "'. Esperado '" + simb.tipo + "', recebido '" + rhs.tipo + "'.");
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
        // $1 representa os atributos do token TK_STRING vindos do lexer
        // $1.tamanho_string agora contém o comprimento exato da string,
        // calculado durante a compilação!
        
        $$.label = gentempcode();
        $$.tipo = "string";
        declaracoes_temp[$$.label] = "string";
        
        // Aloca memória com o tamanho exato (+1 para o '\0')
        int tamanho_necessario = $1.tamanho_string + 1;
        
        $$.traducao = "\t" + $$.label + " = (char*) malloc(" + to_string(tamanho_necessario) + ");\n";
        // Copia a string literal para a memória recém-alocada
        $$.traducao += "\tstrcpy(" + $$.label + ", " + $1.label + ");\n";
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