#define YYSTYPE atributos

using namespace std;
int goto_label_qnt = 0;
int var_temp_qnt = 0;
int contador_linha = 1;
string codigo_funcoes_auxiliares;
bool funcao_strlen_gerada = false;
vector<string> strings_a_liberar;
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
    atrib.literal = false;
    if (tipo_var == "string") {
        atrib.tamanho_string = -1; // -1 indica tamanho desconhecido
    } else {
        atrib.tamanho_string = 0; // Para outros tipos, não é usado
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

                    if (tipo_linguagem == "string") {
                        if(!(it_orig_name != p_mapa_c_para_original.end())){
                            tipo_c_str = "char*";
                            codigo_local += "\t" + tipo_c_str + " " + c_name + ";";
                        }else{
                            tipo_c_str = "char*";
                            codigo_local += "\t" + tipo_c_str + " " + c_name + " = NULL;";
                        }
                        
                    } else {
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

atributos gerar_codigo_concatenacao(atributos str1, atributos str2) {
    gerar_funcao_strlen_se_necessario();

    atributos res;
    res.tipo = "string";
    res.literal = false;
    res.label = gentempcode();
    declaracoes_temp[res.label] = "string";

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
        declaracoes_temp[len1_temp] = "int";
        codigo += "\t" + len1_temp + " = obter_tamanho_string(" + str1.label + ");\n";
        len1_str = len1_temp;
    }

    if (str2.tamanho_string >= 0) {
        len2_str = to_string(str2.tamanho_string);
    } else if (!str2.label_tamanho_runtime.empty()){
        len2_str = str2.label_tamanho_runtime;
    } else {
        string len2_temp = gentempcode();
        declaracoes_temp[len2_temp] = "int";
        codigo += "\t" + len2_temp + " = obter_tamanho_string(" + str2.label + ");\n";
        len2_str = len2_temp;
    }
    
    string soma_parcial_temp = gentempcode();
    declaracoes_temp[soma_parcial_temp] = "int";
    codigo += "\t" + soma_parcial_temp + " = " + len1_str + " + " + len2_str + ";\n";

    if (str1.tamanho_string >= 0 && str2.tamanho_string >= 0) {
        res.tamanho_string = str1.tamanho_string + str2.tamanho_string;
        res.label_tamanho_runtime = "";
    } else {
        res.tamanho_string = -1;
        res.label_tamanho_runtime = soma_parcial_temp;
    }

    string tamanho_total_temp = gentempcode();
    declaracoes_temp[tamanho_total_temp] = "int";
    codigo += "\t" + tamanho_total_temp + " = " + soma_parcial_temp + " + 1;\n";

    codigo += "\t" + res.label + " = (char*) malloc(" + tamanho_total_temp + ");\n";
    codigo += "\tstrcpy(" + res.label + ", " + str1.label + ");\n";
    codigo += "\tstrcat(" + res.label + ", " + str2.label + ");\n";

    res.traducao = codigo;
    return res;
}

atributos criar_expressao_binaria(atributos op1, string op_str_lexical, string op_str_c, atributos op2) {
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
            res.tipo = op.tipo;
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
    string codigo_gerado = string_origem_rhs.traducao;
    string len_var_name;

    if (string_origem_rhs.tamanho_string >= 0) {
        len_var_name = to_string(string_origem_rhs.tamanho_string);
    } else if (!string_origem_rhs.label_tamanho_runtime.empty()) {
        len_var_name = string_origem_rhs.label_tamanho_runtime;
    } else {
        gerar_funcao_strlen_se_necessario();
        string len_temp = gentempcode();
        declaracoes_temp[len_temp] = "int";
        codigo_gerado += "\t" + len_temp + " = obter_tamanho_string(" + string_origem_rhs.label + ");\n";
        len_var_name = len_temp;
    }
    
    string tamanho_total_temp = gentempcode();
    declaracoes_temp[tamanho_total_temp] = "int";
    codigo_gerado += "\t" + tamanho_total_temp + " = " + len_var_name + " + 1;\n";
    codigo_gerado += "\t" + ponteiro_destino_c_name + " = (char*) malloc(" + tamanho_total_temp + ");\n";
    codigo_gerado += "\tstrcpy(" + ponteiro_destino_c_name + ", " + string_origem_rhs.label + ");\n";
    
    return codigo_gerado;
}