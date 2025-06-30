#define YYSTYPE atributos
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>
#include <stack>

using namespace std;
int goto_label_qnt = 0;
int var_temp_qnt = 0;
int contador_linha = 1;
bool funcao_mult_matriz_int_gerada = false;
bool funcao_add_matriz_int_gerada = false;
bool funcao_sub_matriz_int_gerada = false;
bool funcao_mult_matriz_float_gerada = false;
bool funcao_add_matriz_float_gerada = false;
bool funcao_sub_matriz_float_gerada = false;
bool encontrou_retorno_na_funcao_atual = false;

vector<string> strings_a_liberar_no_comando;
string codigo_funcoes_auxiliares;
bool funcao_strlen_gerada = false;
vector<string> strings_a_liberar;

struct ParamInfo {
    string tipo;
    string tipo_base;
    string nome_original;
    string nome_no_c; // Nome que o parâmetro terá no código C gerado
};

struct CaseInfo {
    string valor;
    string tipo;
    string label;
};

struct atributos
{
    string label;
    string traducao;
    string tipo;
    int tamanho_string;
    bool literal;
    string label_tamanho_runtime;

    vector<CaseInfo> cases;
    string default_label;
    string label_final_switch;
    bool eh_vetor;
    bool eh_endereco; 
    string nome_original;
    string tipo_base; 
    string label_linhas;
    string label_colunas;

    int valor_literal;  // Guarda o valor de um número, se for literal
    bool eh_literal;    // Sinaliza se a expressão é um literal conhecido
    int valor_linhas;   // Guarda o valor literal das linhas da matriz
    int valor_colunas;  // Guarda o valor literal das colunas da matriz 

    string kind; // "variable", "function", "function_definition" etc.
    vector<ParamInfo> params; // Guarda a lista de parâmetros de uma função
    vector<atributos> args;   // Guarda a lista de argumentos em uma chamada de função
};

stack<atributos> pilha_funcoes_atuais;
vector<map<string, atributos>> pilha_tabelas_simbolos;
stack<vector<string>> ordem_declaracoes;
stack<map<string, string>> declaracoes_temp;
stack<map<string, string>> mapa_c_para_original;
vector<pair<string, string>> pilha_loops;
vector<pair<string, string>> matrizes_a_liberar;

void gerar_funcao_strlen_se_necessario();

void gerar_funcao_mult_matriz_INT_se_necessario();
void gerar_funcao_add_matriz_INT_se_necessario();
void gerar_funcao_sub_matriz_INT_se_necessario();
void gerar_funcao_mult_matriz_FLOAT_se_necessario();
void gerar_funcao_add_matriz_FLOAT_se_necessario();
void gerar_funcao_sub_matriz_FLOAT_se_necessario();

string contar_string();


static const map<string, string> mapa_tipos_linguagem_para_c = {
        {"int", "int"},
        {"float", "float"},
        {"char", "char"},
        {"boolean", "int"},
        {"string", "char*"},
        {"void", "void"}
};

static const std::map<std::string, int> mapa_tamanhos_tipos = {
    {"int",     4},
    {"float",   4},
    {"char",    1},
    {"boolean", 4}, 
    {"string",  8}  
};
 
int yylex(void);
void yyerror(string);
string gentempcode();

string genlabel(){
    return "G" + to_string(++goto_label_qnt);
}

string genuniquename() {
    return "t" + to_string(++var_temp_qnt);
}

atributos desreferenciar_se_necessario(atributos op) {
    // Se não for um endereço, não há nada a fazer.
    if (!op.eh_endereco) {
        return op; 
    }

    atributos res;
    string c_type_do_valor; // Variável para guardar o tipo C correto do valor.

    // --- LÓGICA CORRIGIDA AQUI ---
    // Precisamos determinar qual o tipo C do valor que obteremos com o '*'.
    if (op.tipo == "vetor") {
        // Se a expressão é um endereço para um "vetor" (como em a[0]),
        // o valor real que pegamos é um PONTEIRO para o tipo base (ex: char*).
        c_type_do_valor = mapa_tipos_linguagem_para_c.at(op.tipo_base) + "*";
    } else {
        // Para todos os outros casos (endereço de int, float, char),
        // o tipo do valor é o mesmo tipo da expressão.
        c_type_do_valor = op.tipo;
    }

    res.tipo = c_type_do_valor;
    res.label = gentempcode();
    
    // Registra o temporário para declaração com o tipo C correto!
    declaracoes_temp.top()[res.label] = res.tipo;
    
    // Gera o código da desreferência
    res.traducao = op.traducao + "\t" + res.label + " = *" + op.label + ";\n";
    
    // O resultado agora é um valor, não mais um endereço.
    res.eh_endereco = false; 
    res.eh_vetor = (res.tipo.back() == '*'); // É um vetor se seu novo tipo C ainda for um ponteiro.

    return res;
}
atributos converter_implicitamente(atributos op, string tipo_destino) {
    if (op.tipo == tipo_destino) return op;

    if ((op.tipo == "int" && tipo_destino == "float") || (op.tipo == "float" && tipo_destino == "int")) {
        atributos convertido;
        convertido.label = gentempcode();
        convertido.tipo = tipo_destino;
        convertido.traducao = op.traducao + "\t" + convertido.label + " = (" + tipo_destino + ") " + op.label + ";\n";
        declaracoes_temp.top()[convertido.label] = tipo_destino;
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
    atrib.literal = false;
    atrib.tamanho_string = 0;
    atrib.label_tamanho_runtime = "";
    atrib.eh_vetor = false;
    atrib.eh_endereco = false;
    atrib.nome_original = nome_original;
    atrib.tipo_base = "";
    atrib.valor_literal = 0;
    atrib.eh_literal = false;
    atrib.valor_linhas = -1;
    atrib.valor_colunas = -1;

    if (tipo_var == "string") {
        atrib.tamanho_string = -1;
    }

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

void atualizar_info_string_simbolo(const string& nome_variavel, atributos rhs) {
     atributos* simb_ptr = buscar_simbolo(nome_variavel);
    if (simb_ptr) {
        simb_ptr->tamanho_string = rhs.tamanho_string;
        simb_ptr->label_tamanho_runtime = rhs.label_tamanho_runtime;
    }
}

void entrar_escopo() {
    pilha_tabelas_simbolos.emplace_back();
    ordem_declaracoes.push({});
    declaracoes_temp.push({});
    mapa_c_para_original.push({});
}

void sair_escopo() {
    if (!pilha_tabelas_simbolos.empty()) {
        pilha_tabelas_simbolos.pop_back();
        ordem_declaracoes.pop();
        declaracoes_temp.pop();
        mapa_c_para_original.pop();
    } else {
        cerr << "Erro crítico: Tentativa de sair de escopo com pilha vazia!" << endl;
    }
}

string gerar_codigo_declaracoes() {
    string codigo_local;
    // Pega as listas do topo da pilha (escopo atual)
    vector<string>& ordem_declaracoes_atual = ordem_declaracoes.top();
    map<string, string>& declaracoes_temp_atual = declaracoes_temp.top();
    map<string, string>& mapa_c_para_original_atual = mapa_c_para_original.top();

    for (const auto &c_name : ordem_declaracoes_atual) {
        auto it_decl_type = declaracoes_temp_atual.find(c_name);
        if (it_decl_type != declaracoes_temp_atual.end()) {
            const string& tipo_linguagem = it_decl_type->second;
            string tipo_c_str = "";

            if (tipo_linguagem.find('*') != string::npos) {
                tipo_c_str = tipo_linguagem;
            } else if (tipo_linguagem == "string") {
                tipo_c_str = "char*";
                auto it_orig_name = mapa_c_para_original_atual.find(c_name);
                if (it_orig_name != mapa_c_para_original_atual.end()) {
                    codigo_local += "\t" + tipo_c_str + " " + c_name + " = NULL; // " + it_orig_name->second + "\n";
                    continue;
                }
            } else {
                auto it_mapa_tipos = mapa_tipos_linguagem_para_c.find(tipo_linguagem);
                if (it_mapa_tipos != mapa_tipos_linguagem_para_c.end()) {
                    tipo_c_str = it_mapa_tipos->second;
                }
            }
            if (!tipo_c_str.empty()) {
                codigo_local += "\t" + tipo_c_str + " " + c_name + ";";
                auto it_orig_name = mapa_c_para_original_atual.find(c_name);
                if (it_orig_name != mapa_c_para_original_atual.end()) {
                    codigo_local += " // " + it_orig_name->second;
                }
                codigo_local += "\n";
            }
        }
    }
    return codigo_local;
}

atributos gerar_codigo_concatenacao(atributos str1, atributos str2) {
    gerar_funcao_strlen_se_necessario();

    atributos res;
    res.tipo = "string";
    res.literal = false;
    res.label = gentempcode();
    declaracoes_temp.top()[res.label] = "string";

    strings_a_liberar_no_comando.push_back(res.label);
    string codigo;
    codigo += str1.traducao;
    codigo += str2.traducao;

    string len1_str;
    string len2_str;

    if (str1.tamanho_string >= 0) {
        len1_str = to_string(str1.tamanho_string);
    } else if (!str1.label_tamanho_runtime.empty()){
        len1_str = str1.label_tamanho_runtime;
    } else {
        string len1_temp = gentempcode();
        declaracoes_temp.top()[len1_temp] = "int";
        codigo += "\t" + len1_temp + " = obter_tamanho_string(" + str1.label + ");\n";
        len1_str = len1_temp;
    }

    if (str2.tamanho_string >= 0) {
        len2_str = to_string(str2.tamanho_string);
    } else if (!str2.label_tamanho_runtime.empty()){
        len2_str = str2.label_tamanho_runtime;
    } else {
        string len2_temp = gentempcode();
        declaracoes_temp.top()[len2_temp] = "int";
        codigo += "\t" + len2_temp + " = obter_tamanho_string(" + str2.label + ");\n";
        len2_str = len2_temp;
    }
    
    string soma_parcial_temp = gentempcode();
    declaracoes_temp.top()[soma_parcial_temp] = "int";
    codigo += "\t" + soma_parcial_temp + " = " + len1_str + " + " + len2_str + ";\n";

    if (str1.tamanho_string >= 0 && str2.tamanho_string >= 0) {
        res.tamanho_string = str1.tamanho_string + str2.tamanho_string;
        res.label_tamanho_runtime = "";
    } else {
        res.tamanho_string = -1;
        res.label_tamanho_runtime = soma_parcial_temp;
    }

    string tamanho_total_temp = gentempcode();
    declaracoes_temp.top()[tamanho_total_temp] = "int";
    codigo += "\t" + tamanho_total_temp + " = " + soma_parcial_temp + " + 1;\n";

    codigo += "\t" + res.label + " = (char*) malloc(" + tamanho_total_temp + ");\n";
    codigo += "\tstrcpy(" + res.label + ", " + str1.label + ");\n";
    codigo += "\tstrcat(" + res.label + ", " + str2.label + ");\n";

    res.traducao = codigo;
    return res;
}

atributos criar_expressao_binaria(atributos op1, string op_str_lexical, string op_str_c, atributos op2) {
    // --- BLOCO DE OPERAÇÕES COM MATRIZES (AGORA SUPORTA INT E FLOAT) ---
    if (op1.tipo == "matriz" && op2.tipo == "matriz") {
        
        // Verificação de tipo base (comum a todas as operações)
        if (op1.tipo_base != op2.tipo_base) {
            yyerror("Erro Semantico: Matrizes com tipos base incompativeis ('" + op1.tipo_base + "' e '" + op2.tipo_base + "').");
            return atributos();
        }
        
        // Verificação de dimensões em tempo de compilação (se as dimensões forem literais)
        if (op1.valor_colunas != -1 && op1.valor_linhas != -1 && op2.valor_colunas != -1 && op2.valor_linhas != -1) {
            if (op_str_lexical == "*") {
                if (op1.valor_colunas != op2.valor_linhas) {
                    string erro_msg = "Erro de Compilacao: Dimensoes incompativeis para multiplicacao!";
                    yyerror(erro_msg); return atributos();
                }
            } else if (op_str_lexical == "+" || op_str_lexical == "-") {
                if (op1.valor_linhas != op2.valor_linhas || op1.valor_colunas != op2.valor_colunas) {
                    string erro_msg = "Erro de Compilacao: Dimensoes incompativeis para soma/subtracao de matrizes!";
                    yyerror(erro_msg); return atributos();
                }
            }
        }

        atributos res;
        string func_name;
        
        // Determina qual função auxiliar chamar e as dimensões da matriz resultante
        if (op_str_lexical == "*") {
            // --- LÓGICA GENERALIZADA PARA * ---
            if (op1.tipo_base == "int") { func_name = "MULT_MATRIZ_INT"; gerar_funcao_mult_matriz_INT_se_necessario(); }
            else if (op1.tipo_base == "float") { func_name = "MULT_MATRIZ_FLOAT"; gerar_funcao_mult_matriz_FLOAT_se_necessario(); }
            else { yyerror("Multiplicacao de matrizes so suporta 'int' e 'float'."); return atributos(); }
            
            res.label_linhas = op1.label_linhas; res.label_colunas = op2.label_colunas;
            res.valor_linhas = op1.valor_linhas; res.valor_colunas = op2.valor_colunas;
        } 
        else if (op_str_lexical == "+") {
            // --- LÓGICA GENERALIZADA PARA + ---
            if (op1.tipo_base == "int") { func_name = "ADD_MATRIZ_INT"; gerar_funcao_add_matriz_INT_se_necessario(); }
            else if (op1.tipo_base == "float") { func_name = "ADD_MATRIZ_FLOAT"; gerar_funcao_add_matriz_FLOAT_se_necessario(); }
            else { yyerror("Soma de matrizes so suporta 'int' e 'float'."); return atributos(); }

            res.label_linhas = op1.label_linhas; res.label_colunas = op1.label_colunas;
            res.valor_linhas = op1.valor_linhas; res.valor_colunas = op1.valor_colunas;
        } 
        else if (op_str_lexical == "-") {
            // --- LÓGICA GENERALIZADA PARA - ---
            if (op1.tipo_base == "int") { func_name = "SUB_MATRIZ_INT"; gerar_funcao_sub_matriz_INT_se_necessario(); }
            else if (op1.tipo_base == "float") { func_name = "SUB_MATRIZ_FLOAT"; gerar_funcao_sub_matriz_FLOAT_se_necessario(); }
            else { yyerror("Subtracao de matrizes so suporta 'int' e 'float'."); return atributos(); }

            res.label_linhas = op1.label_linhas; res.label_colunas = op1.label_colunas;
            res.valor_linhas = op1.valor_linhas; res.valor_colunas = op1.valor_colunas;
        } 
        else {
            yyerror("Erro Semantico: O operador '" + op_str_lexical + "' nao e valido entre duas matrizes.");
            return atributos();
        }

        // Lógica comum para preparar atributos, declarar e gerar a chamada à função
        res.label = gentempcode();
        res.tipo = "matriz";
        res.tipo_base = op1.tipo_base;
        res.nome_original = res.label;
        
        string tipo_c_resultado = mapa_tipos_linguagem_para_c.at(res.tipo_base) + "**";
        declaracoes_temp.top()[res.label] = tipo_c_resultado;

        res.traducao = op1.traducao + op2.traducao; 
        res.traducao += "\t" + res.label + " = " + func_name + "(" 
                      + op1.label + ", " + op1.label_linhas + ", " + op1.label_colunas + ", "
                      + op2.label + ", " + op2.label_linhas + ", " + op2.label_colunas + ");\n";
        
        matrizes_a_liberar.push_back(make_pair(res.label, res.label_linhas));
        return res;
    }
    
    // O resto da sua função para inteiros, floats, strings, etc., continua daqui para baixo
    atributos res;
    string tipo_final_operacao = "error";

    bool eh_comparacao = (op_str_c == "<" || op_str_c == ">" || op_str_c == "<=" || op_str_c == ">=" || op_str_c == "==" || op_str_c == "!=");
    bool eh_logico_e_ou = (op_str_lexical == "&" || op_str_lexical == "|"); 
    if (op1.tipo == "string" && op2.tipo == "string") {
        if (op_str_lexical == "+") {
            return gerar_codigo_concatenacao(op1, op2);
        } else {
            yyerror("Erro Semantico: O operador '" + op_str_lexical + "' nao pode ser aplicado a strings.");
            atributos erro;
            erro.tipo = "error";
            return erro;
        }
    }
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
        } else {
            tipo_final_operacao = op1.tipo; 
        }
    }

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

    res.label = gentempcode();
    declaracoes_temp.top()[res.label] = res.tipo; 
    res.traducao = op1.traducao + op2.traducao +
                                         "\t" + res.label + " = " + op1.label + " " + op_str_c + " " + op2.label + ";\n";
    return res;
}
atributos criar_expressao_unaria(atributos op, string op_str_lexical) {
    atributos res;
    if (op.tipo != "boolean" || op_str_lexical != "~") {
        if (op.tipo == "int" || op.tipo == "float") {
            res.label = op.label;
            res.tipo = op.tipo;
            declaracoes_temp.top()[res.label] = res.tipo;
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
    declaracoes_temp.top()[res.label] = res.tipo;
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
    string codigo_gerado = string_origem_rhs.traducao;
    string len_var_name;

    if (string_origem_rhs.tamanho_string >= 0) {
        len_var_name = to_string(string_origem_rhs.tamanho_string);
    } else if (!string_origem_rhs.label_tamanho_runtime.empty()) {
        len_var_name = string_origem_rhs.label_tamanho_runtime;
    } else {
        gerar_funcao_strlen_se_necessario();
        string len_temp = gentempcode();
        declaracoes_temp.top()[len_temp] = "int";
        codigo_gerado += "\t" + len_temp + " = obter_tamanho_string(" + string_origem_rhs.label + ");\n";
        len_var_name = len_temp;
    }
    
    string tamanho_total_temp = gentempcode();
    declaracoes_temp.top()[tamanho_total_temp] = "int";
    codigo_gerado += "\t" + tamanho_total_temp + " = " + len_var_name + " + 1;\n";
    codigo_gerado += "\t" + ponteiro_destino_c_name + " = (char*) malloc(" + tamanho_total_temp + ");\n";
    codigo_gerado += "\tstrcpy(" + ponteiro_destino_c_name + ", " + string_origem_rhs.label + ");\n";
    
    return codigo_gerado;
}

string gerar_codigo_de_liberacao() {
    string codigo_final;

    // 1. Liberação de strings e vetores simples
    for (const auto& var_name : strings_a_liberar) {
        codigo_final += "\tfree(" + var_name + ");\n";
    }
    strings_a_liberar.clear();

    // 2. Liberação de Matrizes
    for (const auto& mat_info : matrizes_a_liberar) {
        string mat_ptr_name = mat_info.first;
        string rows_var_name = mat_info.second;

        // Gera temporários e rótulos para o laço de free
        string free_loop_counter = gentempcode();
        string free_cond_var = gentempcode();
        string free_addr_ptr = gentempcode();
        string free_row_ptr = gentempcode();
        string free_loop_start = genlabel();
        string free_loop_end = genlabel();
        
        
        declaracoes_temp.top()[free_loop_counter] = "int";
        declaracoes_temp.top()[free_cond_var] = "boolean";
        declaracoes_temp.top()[free_addr_ptr] = "void**";
        declaracoes_temp.top()[free_row_ptr] = "void*";

       
        codigo_final += "\n\t// Liberando a matriz " + mat_ptr_name + "\n";
        codigo_final += "\t" + free_loop_counter + " = 0;\n";
        codigo_final += free_loop_start + ":\n";
        codigo_final += "\t\t" + free_cond_var + " = " + free_loop_counter + " < " + rows_var_name + ";\n";
        codigo_final += "\t\tif (!" + free_cond_var + ") goto " + free_loop_end + ";\n";
        
        codigo_final += "\t\t" + free_addr_ptr + " = (void**)" + mat_ptr_name + " + " + free_loop_counter + ";\n";
        codigo_final += "\t\t" + free_row_ptr + " = *" + free_addr_ptr + ";\n";
        codigo_final += "\t\tfree(" + free_row_ptr + ");\n";

        codigo_final += "\t\t" + free_loop_counter + " = " + free_loop_counter + " + 1;\n";
        codigo_final += "\t\tgoto " + free_loop_start + ";\n";
        codigo_final += free_loop_end + ":\n";

        // Libera o ponteiro principal da matriz
        codigo_final += "\tfree(" + mat_ptr_name + ");\n";
    }
    matrizes_a_liberar.clear();

    return codigo_final;
}
void gerar_funcao_add_matriz_INT_se_necessario() {
    if (funcao_add_matriz_int_gerada) return;
    funcao_add_matriz_int_gerada = true;
    codigo_funcoes_auxiliares += R"(
int** ADD_MATRIZ_INT(int** matA, int linhasA, int colunasA, int** matB, int linhasB, int colunasB) {
    if (linhasA != linhasB || colunasA != colunasB) {
        printf("Erro de execucao: Dimensoes incompativeis para soma de matrizes! (%dx%d e %dx%d)\n", linhasA, colunasA, linhasB, colunasB);
        exit(1);
    }
    int** matC = (int**) malloc(linhasA * sizeof(int*));
    int i = 0, j = 0, cond = 0;
    int** ptr_addr_linha_C;
    int* ptr_linha_A, *ptr_linha_B, *ptr_linha_C_inner;
    int* ptr_elem_A, *ptr_elem_B, *ptr_elem_C;

L_ALLOC_START:
    cond = i < linhasA;
    if (!cond) goto L_ALLOC_END;
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (int*) malloc(colunasA * sizeof(int));
    i = i + 1;
    goto L_ALLOC_START;
L_ALLOC_END:

    i = 0;
L_LOOP_I_START:
    cond = i < linhasA;
    if (!cond) goto L_LOOP_I_END;
    j = 0;
L_LOOP_J_START:
    cond = j < colunasA;
    if (!cond) goto L_LOOP_J_END;

    ptr_linha_A = *(matA + i);
    ptr_elem_A = ptr_linha_A + j;

    ptr_linha_B = *(matB + i);
    ptr_elem_B = ptr_linha_B + j;

    ptr_linha_C_inner = *(matC + i);
    ptr_elem_C = ptr_linha_C_inner + j;

    *ptr_elem_C = *ptr_elem_A + *ptr_elem_B;

    j = j + 1;
    goto L_LOOP_J_START;
L_LOOP_J_END:
    i = i + 1;
    goto L_LOOP_I_START;
L_LOOP_I_END:
    return matC;
}

)";
}


void gerar_funcao_sub_matriz_INT_se_necessario() {
    if (funcao_sub_matriz_int_gerada) return;
    funcao_sub_matriz_int_gerada = true;
    codigo_funcoes_auxiliares += R"(
int** SUB_MATRIZ_INT(int** matA, int linhasA, int colunasA, int** matB, int linhasB, int colunasB) {
    if (linhasA != linhasB || colunasA != colunasB) {
        printf("Erro de execucao: Dimensoes incompativeis para subtracao de matrizes! (%dx%d e %dx%d)\n", linhasA, colunasA, linhasB, colunasB);
        exit(1);
    }
    int** matC = (int**) malloc(linhasA * sizeof(int*));
    int i = 0, j = 0, cond = 0;
    int** ptr_addr_linha_C;
    int* ptr_linha_A, *ptr_linha_B, *ptr_linha_C_inner;
    int* ptr_elem_A, *ptr_elem_B, *ptr_elem_C;

L_ALLOC_START:
    cond = i < linhasA;
    if (!cond) goto L_ALLOC_END;
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (int*) malloc(colunasA * sizeof(int));
    i = i + 1;
    goto L_ALLOC_START;
L_ALLOC_END:

    i = 0;
L_LOOP_I_START:
    cond = i < linhasA;
    if (!cond) goto L_LOOP_I_END;
    j = 0;
L_LOOP_J_START:
    cond = j < colunasA;
    if (!cond) goto L_LOOP_J_END;

    ptr_linha_A = *(matA + i);
    ptr_elem_A = ptr_linha_A + j;

    ptr_linha_B = *(matB + i);
    ptr_elem_B = ptr_linha_B + j;

    ptr_linha_C_inner = *(matC + i);
    ptr_elem_C = ptr_linha_C_inner + j;

    *ptr_elem_C = *ptr_elem_A - *ptr_elem_B;

    j = j + 1;
    goto L_LOOP_J_START;
L_LOOP_J_END:
    i = i + 1;
    goto L_LOOP_I_START;
L_LOOP_I_END:
    return matC;
}

)";
}

void gerar_funcao_mult_matriz_INT_se_necessario() {
    if (funcao_mult_matriz_int_gerada) {
        return; // Se já foi gerada, não faz nada
    }
    funcao_mult_matriz_int_gerada = true;

    // A MUDANÇA: Em vez de 'return R"(...)"', adicionamos à variável global.
    codigo_funcoes_auxiliares += R"(
int** MULT_MATRIZ_INT(int** matA, int linhasA, int colunasA, int** matB, int linhasB, int colunasB) {
    // Declaração de todas as variáveis locais necessárias
    int linhasC, colunasC;
    int** matC;
    int i;
    int j;
    int k;
    int cond;

    // Ponteiros temporários para aritmética
    int** ptr_addr_linha_C;
    int* ptr_linha_A;
    int* ptr_linha_B;
    int* ptr_linha_C_inner;
    int* ptr_elem_A;
    int* ptr_elem_B;
    int* ptr_elem_C;
    int   valA, valB, val_atual_C;

    // 1. Verificação de dimensão
    if (colunasA != linhasB) {
        printf("Erro de execucao: Dimensoes incompativeis para multiplicacao! Colunas de A (%d) != Linhas de B (%d)\n", colunasA, linhasB);
        exit(1);
    }

    // 2. Alocação da matriz resultante C (linhasA x colunasB) sem 'for'
    linhasC = linhasA;
    colunasC = colunasB;
    matC = (int**) malloc(linhasC * sizeof(int*));
    
    i = 0;
L_ALLOC_START:
    cond = i < linhasC;
    if (!cond) goto L_ALLOC_END;
    
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (int*) malloc(colunasC * sizeof(int));
    
    i = i + 1;
    goto L_ALLOC_START;
L_ALLOC_END:

    // 3. O cálculo da multiplicação (3 laços aninhados com GOTO)
    i = 0;
L_LOOP_I_START:
    cond = i < linhasC;
    if (!cond) goto L_LOOP_I_END;

    j = 0;
L_LOOP_J_START:
    cond = j < colunasC;
    if (!cond) goto L_LOOP_J_END;

    // Inicializa C[i][j] = 0
    ptr_linha_C_inner = *(matC + i);
    ptr_elem_C = ptr_linha_C_inner + j;
    *ptr_elem_C = 0;

    k = 0;
L_LOOP_K_START:
    cond = k < colunasA;
    if (!cond) goto L_LOOP_K_END;
    
    // Cálculo: C[i][j] += A[i][k] * B[k][j];
    ptr_linha_A = *(matA + i);
    ptr_elem_A = ptr_linha_A + k;
    valA = *ptr_elem_A;

    ptr_linha_B = *(matB + k);
    ptr_elem_B = ptr_linha_B + j;
    valB = *ptr_elem_B;
    
    val_atual_C = *ptr_elem_C;
    *ptr_elem_C = val_atual_C + (valA * valB);

    k = k + 1;
    goto L_LOOP_K_START;
L_LOOP_K_END:

    j = j + 1;
    goto L_LOOP_J_START;
L_LOOP_J_END:

    i = i + 1;
    goto L_LOOP_I_START;
L_LOOP_I_END:

    return matC;
}

)";
}

void gerar_funcao_add_matriz_FLOAT_se_necessario() {
    if (funcao_add_matriz_float_gerada) return;
    funcao_add_matriz_float_gerada = true;
    codigo_funcoes_auxiliares += R"(
float** ADD_MATRIZ_FLOAT(float** matA, int linhasA, int colunasA, float** matB, int linhasB, int colunasB) {
    if (linhasA != linhasB || colunasA != colunasB) { exit(1); }
    float** matC = (float**) malloc(linhasA * sizeof(float*));
    int i = 0, j = 0, cond = 0;
    float** ptr_addr_linha_C;
    float* ptr_linha_A, *ptr_linha_B, *ptr_linha_C_inner;
    float* ptr_elem_A, *ptr_elem_B, *ptr_elem_C;
L_ALLOC_START:
    cond = i < linhasA; if (!cond) goto L_ALLOC_END;
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (float*) malloc(colunasA * sizeof(float));
    i = i + 1; goto L_ALLOC_START;
L_ALLOC_END:
    i = 0;
L_LOOP_I_START:
    cond = i < linhasA; if (!cond) goto L_LOOP_I_END;
    j = 0;
L_LOOP_J_START:
    cond = j < colunasA; if (!cond) goto L_LOOP_J_END;
    ptr_linha_A = *(matA + i); ptr_elem_A = ptr_linha_A + j;
    ptr_linha_B = *(matB + i); ptr_elem_B = ptr_linha_B + j;
    ptr_linha_C_inner = *(matC + i); ptr_elem_C = ptr_linha_C_inner + j;
    *ptr_elem_C = *ptr_elem_A + *ptr_elem_B;
    j = j + 1; goto L_LOOP_J_START;
L_LOOP_J_END:
    i = i + 1; goto L_LOOP_I_START;
L_LOOP_I_END:
    return matC;
}
)";
}

// --- SUBTRAÇÃO DE FLOAT ---
void gerar_funcao_sub_matriz_FLOAT_se_necessario() {
    if (funcao_sub_matriz_float_gerada) return;
    funcao_sub_matriz_float_gerada = true;
    codigo_funcoes_auxiliares += R"(
float** SUB_MATRIZ_FLOAT(float** matA, int linhasA, int colunasA, float** matB, int linhasB, int colunasB) {
    if (linhasA != linhasB || colunasA != colunasB) { exit(1); }
    float** matC = (float**) malloc(linhasA * sizeof(float*));
    int i = 0, j = 0, cond = 0;
    float** ptr_addr_linha_C;
    float* ptr_linha_A, *ptr_linha_B, *ptr_linha_C_inner;
    float* ptr_elem_A, *ptr_elem_B, *ptr_elem_C;
L_ALLOC_START:
    cond = i < linhasA; if (!cond) goto L_ALLOC_END;
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (float*) malloc(colunasA * sizeof(float));
    i = i + 1; goto L_ALLOC_START;
L_ALLOC_END:
    i = 0;
L_LOOP_I_START:
    cond = i < linhasA; if (!cond) goto L_LOOP_I_END;
    j = 0;
L_LOOP_J_START:
    cond = j < colunasA; if (!cond) goto L_LOOP_J_END;
    ptr_linha_A = *(matA + i); ptr_elem_A = ptr_linha_A + j;
    ptr_linha_B = *(matB + i); ptr_elem_B = ptr_linha_B + j;
    ptr_linha_C_inner = *(matC + i); ptr_elem_C = ptr_linha_C_inner + j;
    *ptr_elem_C = *ptr_elem_A - *ptr_elem_B;
    j = j + 1; goto L_LOOP_J_START;
L_LOOP_J_END:
    i = i + 1; goto L_LOOP_I_START;
L_LOOP_I_END:
    return matC;
}
)";
}

// --- MULTIPLICAÇÃO DE FLOAT ---
void gerar_funcao_mult_matriz_FLOAT_se_necessario() {
    if (funcao_mult_matriz_float_gerada) return;
    funcao_mult_matriz_float_gerada = true;
    codigo_funcoes_auxiliares += R"(
float** MULT_MATRIZ_FLOAT(float** matA, int linhasA, int colunasA, float** matB, int linhasB, int colunasB) {
    if (colunasA != linhasB) { exit(1); }
    int linhasC = linhasA, colunasC = colunasB;
    float** matC = (float**) malloc(linhasC * sizeof(float*));
    int i=0, j=0, k=0, cond=0;
    float** ptr_addr_linha_C;
    float* ptr_linha_A, *ptr_linha_B, *ptr_linha_C_inner;
    float* ptr_elem_A, *ptr_elem_B, *ptr_elem_C;
    float valA, valB, val_atual_C;
L_ALLOC_START:
    cond = i < linhasC; if (!cond) goto L_ALLOC_END;
    ptr_addr_linha_C = matC + i;
    *ptr_addr_linha_C = (float*) malloc(colunasC * sizeof(float));
    i = i + 1; goto L_ALLOC_START;
L_ALLOC_END:
    i = 0;
L_LOOP_I_START:
    cond = i < linhasC; if (!cond) goto L_LOOP_I_END;
    j = 0;
L_LOOP_J_START:
    cond = j < colunasC; if (!cond) goto L_LOOP_J_END;
    ptr_linha_C_inner = *(matC + i);
    ptr_elem_C = ptr_linha_C_inner + j;
    *ptr_elem_C = 0.0;
    k = 0;
L_LOOP_K_START:
    cond = k < colunasA; if (!cond) goto L_LOOP_K_END;
    ptr_linha_A = *(matA + i); ptr_elem_A = ptr_linha_A + k; valA = *ptr_elem_A;
    ptr_linha_B = *(matB + k); ptr_elem_B = ptr_linha_B + j; valB = *ptr_elem_B;
    val_atual_C = *ptr_elem_C;
    *ptr_elem_C = val_atual_C + (valA * valB);
    k = k + 1; goto L_LOOP_K_START;
L_LOOP_K_END:
    j = j + 1; goto L_LOOP_J_START;
L_LOOP_J_END:
    i = i + 1; goto L_LOOP_I_START;
L_LOOP_I_END:
    return matC;
}
)";
}


