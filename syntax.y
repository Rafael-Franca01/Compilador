%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>
#include "lib.hpp"	



%}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR TK_STRING
%token TK_MAIN TK_IF TK_ELSE TK_WHILE TK_FOR TK_DO TK_PRINT TK_SCANF TK_BREAK TK_CONTINUE
%token TK_SWITCH TK_CASE TK_DEFAULT 
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
        string includes = "//Compilador PCD\n"
                        "#include <iostream>\n"
                        "#include <string.h>\n" 
                        "#include <stdlib.h>\n"
                        "#include <stdio.h>\n\n"; 
    cout << includes << codigo_funcoes_auxiliares << $1.traducao << endl;
    }

SEXO : S SEXO
    { $$.traducao = $1.traducao + $2.traducao; }
    |   { $$.traducao = ""; }
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

        // Adicione este bloco para liberar a memória
        string codigo_liberacao;
        for (const auto& var_name : strings_a_liberar) {
            codigo_liberacao += "\tfree(" + var_name + ");\n";
        }
        codigo += codigo_liberacao;
        strings_a_liberar.clear();

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
                $3.literal = false; // Força a leitura de string como entrada dinâmica
                string len_temp = gentempcode();
                string cap_temp = gentempcode();
                string char_in_temp = gentempcode();
                string scanf_ret_temp = gentempcode();
                string ptr_dest_temp = gentempcode();
                string cond_temp = gentempcode();
                string cap_limit_temp = gentempcode();
                string L_loop_start = genlabel();
                string L_fim_loop = genlabel();
                string L_skip_realloc = genlabel();
                
                // Variáveis para a verificação do free
                string free_cond_temp = gentempcode();
                string L_skip_free = genlabel();

                $$.traducao += "\t{\n";
                $$.traducao += "\t\tint " + len_temp + " = 0;\n";
                $$.traducao += "\t\tint " + cap_temp + " = 32;\n";
                $$.traducao += "\t\tchar " + char_in_temp + ";\n";
                $$.traducao += "\t\tint " + scanf_ret_temp + ";\n";
                $$.traducao += "\t\tchar* " + ptr_dest_temp + ";\n";
                $$.traducao += "\t\tint " + cond_temp + ";\n";
                $$.traducao += "\t\tint " + free_cond_temp + ";\n"; 
                $$.traducao += "\t\tint " + cap_limit_temp + ";\n";

                // verifica se a variavel ja foi alocada
                $$.traducao += "\t\t" + free_cond_temp + " = " + c_var_name + " != NULL;\n";
                $$.traducao += "\t\tif (!" + free_cond_temp + ") goto " + L_skip_free + ";\n";
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
                if (var_tipo == "int") format_specifier = "%d";
                else if (var_tipo == "float") format_specifier = "%f";
                else if (var_tipo == "char") format_specifier = " %c"; 
                else if (var_tipo == "boolean"){
                    string temp_int_scanf = gentempcode();  \
                    
                    string temp_condicao = gentempcode();  
                    string label_set_zero = genlabel();
                    string label_end = genlabel();
                    
                    
                    declaracoes_temp[temp_int_scanf] = "int";
                    declaracoes_temp[temp_condicao] = "boolean"; 

                    
                    string codigo_gerado;
                    
                    
                    codigo_gerado += "\tscanf(\"%d\", &" + temp_int_scanf + ");\n";
                    codigo_gerado += "\t" + temp_condicao + " = " + temp_int_scanf + " == 0;\n";
                    codigo_gerado += "\tif (" + temp_condicao + ") goto " + label_set_zero + ";\n";


                    // Bloco para caso a condição seja falsa (valor lido != 0)
                    codigo_gerado += "\t" + c_var_name + " = 1;\n";
                    codigo_gerado += "\tgoto " + label_end + ";\n"; 
                    
                    // Bloco para caso a condição seja verdadeira (valor lido == 0)
                    codigo_gerado += label_set_zero + ":\n";
                    codigo_gerado += "\t" + c_var_name + " = 0;\n";
                    
 
                    codigo_gerado += label_end + ":\n";

                    $$.traducao = codigo_gerado;
                }
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
            yyerror("Erro: 'brk' fora de um loop ou switch.");
            $$ = atributos();
        } else {
            string label_fim_loop = pilha_loops.back().first;
            $$.traducao = "\tgoto " + label_fim_loop + ";\n";
        }
    }
    |TK_CONTINUE ';'
    {
        if (pilha_loops.empty() || pilha_loops.back().second.empty()) {
            yyerror("Erro: 'cnt' fora de um loop apropriado.");
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
    | TK_WHILE '(' E ')'
      { 
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

        $$.traducao = label_inicio_while + ":\n";
        $$.traducao += $5.traducao;
        $$.traducao += "\tif (!" + $5.label + "){\n";
        $$.traducao += "\t\tgoto " + label_fim_while + ";\n";
        $$.traducao += "\t}\n";
        $$.traducao += $6.traducao;
        $$.traducao += "\tgoto " + label_inicio_while + ";\n";
        $$.traducao += label_fim_while + ":\n";

        pilha_loops.pop_back();
      }
    | TK_DO M_DO_SETUP BLOCO TK_WHILE '(' E ')' ';'
    {
        string label_inicio_bloco = $2.label;
        string label_fim_loop   = $2.traducao;

        $$.traducao = label_inicio_bloco + ":\n";
        $$.traducao += $3.traducao;
        $$.traducao += $6.traducao;
        $$.traducao += "\tif (" + $6.label + "){\n";
        $$.traducao += "\t\tgoto " + label_inicio_bloco + ";\n";
        $$.traducao += "\t}\n";
        $$.traducao += label_fim_loop + ":\n";

        pilha_loops.pop_back();
    }
    | TK_FOR { entrar_escopo(); } '(' COD ';' E ';'
      { 
        string temp_loop_continue = genlabel(); 
        string temp_loop_break = genlabel();     
        pilha_loops.push_back(make_pair(temp_loop_break, temp_loop_continue));

        $$ = $6; 
      }
      COD ')' BLOCO 
      { 
    pair<string, string> current_loop_labels = pilha_loops.back();
    string label_fim_for = current_loop_labels.first;      // L_FIM
    string label_continue_for = current_loop_labels.second; // L_CONTINUE

    string label_condicao_for = genlabel(); // L_CONDICAO

    // Passo 1: Código de Inicialização
    $$.traducao = $4.traducao;

    // Passo 2: Label da Condição
    $$.traducao += label_condicao_for + ":\n";

    // Passo 3 e 4: Código da Condição e Desvio se Falso
    $$.traducao += $8.traducao; // $8 contém os atributos da condição E ($6)
    $$.traducao += "\tif (!" + $8.label + ") goto " + label_fim_for + ";\n";

    // Passo 5: Código do Corpo do Loop
    $$.traducao += $11.traducao; // Adiciona o bloco de comandos

    // Passo 6: Label do Continue
    $$.traducao += label_continue_for + ":\n";

    // Passo 7: Código do Incremento
    $$.traducao += $9.traducao;

    // Passo 8: Voltar para o Teste da Condição
    $$.traducao += "\tgoto " + label_condicao_for + ";\n"; 

    // Passo 9: Label do Fim do Loop
    $$.traducao += label_fim_for + ":\n";

    pilha_loops.pop_back();
    sair_escopo();
}
    | BLOCO
    {
        $$.traducao = $1.traducao;
    }
    | SWITCH_STMT { $$ = $1; }
    ;

M_DO_SETUP : 
    {
        string continue_label = genlabel();
        string break_label = genlabel();

        pilha_loops.push_back(make_pair(break_label, continue_label));

        $$.label = continue_label;
        $$.traducao = break_label;
        $$.tipo = "do_loop_setup_labels";
    }
    ;

SWITCH_STMT : TK_SWITCH '(' E ')' 
            {
                string label_fim_switch = genlabel();
                pilha_loops.push_back(make_pair(label_fim_switch, ""));

                if ($3.tipo != "int" && $3.tipo != "char") {
                    yyerror("Erro Semantico: Expressao do switch deve ser do tipo 'int' ou 'char', mas eh '" + $3.tipo + "'.");
                }
                $$ = $3;
                $$.label_final_switch = label_fim_switch;
            }
            '{' LISTA_CASES '}'
            {
                atributos expr = $5;
                atributos cases = $7;
                string label_fim_switch = expr.label_final_switch;

                string codigo;
                codigo += expr.traducao;

                for (const auto& case_info : cases.cases) {
                    string literal_temp = gentempcode();
                    declaracoes_temp[literal_temp] = case_info.tipo;

                    codigo += "\t" + literal_temp + " = " + case_info.valor + ";\n";
                    
                    string comp_temp = gentempcode();
                    declaracoes_temp[comp_temp] = "boolean";

                    codigo += "\t" + comp_temp + " = " + expr.label + " == " + literal_temp + ";\n";
                    
                    codigo += "\tif (" + comp_temp + ") goto " + case_info.label + ";\n";
                }

                if (!cases.default_label.empty()) {
                    codigo += "\tgoto " + cases.default_label + ";\n";
                } else {
                    codigo += "\tgoto " + label_fim_switch + ";\n";
                }

                codigo += cases.traducao;
                codigo += label_fim_switch + ":\n";

                pilha_loops.pop_back();
                $$.traducao = codigo;
            }
            ;

LISTA_CASES : CASE_STMT LISTA_CASES
            {
                $$.traducao = $1.traducao + $2.traducao;
                $$.cases = $1.cases;
                $$.cases.insert($$.cases.end(), $2.cases.begin(), $2.cases.end());

                if (!$1.default_label.empty() && !$2.default_label.empty()) {
                    yyerror("Erro Semantico: Multiplos blocos 'default' no mesmo switch.");
                }
                $$.default_label = !$1.default_label.empty() ? $1.default_label : $2.default_label;
            }
            |
            {
                $$.traducao = "";
            }
            ;

CASE_STMT : TK_CASE VALOR_LITERAL ':' COMANDOS
          {
                string case_label = genlabel();
                
                CaseInfo info;
                info.valor = $2.label;
                info.tipo = $2.tipo;
                info.label = case_label;

                $$.cases.push_back(info);

                $$.traducao = case_label + ":\n" + $4.traducao;
          }
          | TK_DEFAULT ':' COMANDOS
          {
                if (!$$.default_label.empty()) {
                     yyerror("Erro Semantico: Bloco 'default' ja foi definido.");
                }
                $$.default_label = genlabel();
                $$.traducao = $$.default_label + ":\n" + $3.traducao;
          }
          ;

VALOR_LITERAL : TK_NUM
			  {
				$$ = $1; 
                $$.tipo = "int";
			  }
			  | TK_CHAR 
              { 
                $$ = $1; 
                $$.tipo = "char";
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
            if ($1.tipo == "string") {
                strings_a_liberar.push_back(c_code_name);
            }
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

        if (tipo_declarado == "string") {
            if ($4.tipo != "string") {
                yyerror("Erro Semantico: tipo incompatível na atribuição da declaração de '" + original_name + "'. Esperado 'string', recebido '" + $4.tipo + "'.");
            } else {
                $$.traducao = contar_string(c_code_name, $4);
                atualizar_info_string_simbolo(original_name, $4);
                strings_a_liberar.push_back(c_code_name);
            }
        } else {
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
    }
};

TIPO : TK_TIPO_INT { $$.tipo = "int"; }
    | TK_TIPO_FLOAT { $$.tipo = "float"; }
    | TK_TIPO_BOOL { $$.tipo = "boolean"; }
    | TK_TIPO_CHAR { $$.tipo = "char"; }
    | TK_TIPO_STRING { $$.tipo = "string"; }
    ;

E : E '+' E                 { $$ = criar_expressao_binaria($1, "+", "+", $3); }
  | E '-' E                 { $$ = criar_expressao_binaria($1, "-", "-", $3); }
  | E '*' E                 { $$ = criar_expressao_binaria($1, "*", "*", $3); }
  | E '/' E                 { $$ = criar_expressao_binaria($1, "/", "/", $3); }
  | E '<' E                 { $$ = criar_expressao_binaria($1, "<", "<", $3); }
  | E '>' E                 { $$ = criar_expressao_binaria($1, ">", ">", $3); }
  | E '&' E                 { $$ = criar_expressao_binaria($1, "&", "&&", $3); }
  | E '|' E                 { $$ = criar_expressao_binaria($1, "|", "||", $3); }
  | E TK_MAIOR_IGUAL E      { $$ = criar_expressao_binaria($1, ">=", ">=", $3); }
  | E TK_MENOR_IGUAL E      { $$ = criar_expressao_binaria($1, "<=", "<=", $3); }
  | E TK_DIFERENTE E        { $$ = criar_expressao_binaria($1, "!=", "!=", $3); }
  | E TK_IGUAL_IGUAL E      { $$ = criar_expressao_binaria($1, "==", "==", $3); }
  | TK_ID '=' E
    {
        atributos* simb_ptr = buscar_simbolo($1.label);
        if (!simb_ptr) {
            yyerror("Erro Semantico: variavel '" + $1.label + "' nao declarada.");
            $$.tipo = "error";
        } else {
            atributos simb = *simb_ptr;
            atributos rhs = $3;

            if (simb.tipo == "string") {
                if (rhs.tipo != "string") {
                    yyerror("Erro Semantico: tipos incompatíveis na atribuicao para '" + $1.label + "'. Esperado 'string', recebido '" + rhs.tipo + "'.");
                    $$.tipo = "error";
                } else {
                    $$.traducao = rhs.traducao;

                  
                    string temp_cond = gentempcode();
                    declaracoes_temp[temp_cond] = "int"; 
                    string label_skip_free = genlabel();

                    $$.traducao += "\t" + temp_cond + " = " + simb.label + " == NULL;\n";
                    $$.traducao += "\tif (" + temp_cond + ") goto " + label_skip_free + ";\n";
                    $$.traducao += "\tfree(" + simb.label + ");\n";
                    $$.traducao += label_skip_free + ":\n";
                   

                    string codigo_copia = contar_string(simb.label, rhs);
                    $$.traducao += codigo_copia.substr(rhs.traducao.length());
                    
                    $$.label = simb.label;
                    $$.tipo = simb.tipo;
                    atualizar_info_string_simbolo($1.label, rhs);
                }
            } else {
                if (simb.tipo != rhs.tipo) {
                    rhs = converter_implicitamente(rhs, simb.tipo);
                }
                $$.traducao = rhs.traducao + "\t" + simb.label + " = " + rhs.label + ";\n";
                $$.label = simb.label;
                $$.tipo = simb.tipo;
            }
        }
    }

  | UNARY_E
    {
        $$.label = $1.label;
        $$.traducao = $1.traducao;
        $$.tipo = $1.tipo;
        $$.tamanho_string = $1.tamanho_string;
        $$.literal = $1.literal;
        $$.cases = $1.cases;
        $$.default_label = $1.default_label;
        $$.label_final_switch = $1.label_final_switch;
        $$.label_tamanho_runtime = $1.label_tamanho_runtime;
    }
  ;

UNARY_E : TK_MAIS_MAIS UNARY_E  { $$ = criar_expressao_unaria($2, "+"); } // Pré-incremento e decremento
        | TK_MENOS_MENOS UNARY_E { $$ = criar_expressao_unaria($2, "-"); } 
        | '~' UNARY_E            { $$ = criar_expressao_unaria($2, "~"); }
        | POSTFIX_E
        {
            $$.label = $1.label;
            $$.traducao = $1.traducao;
            $$.tipo = $1.tipo;
            $$.tamanho_string = $1.tamanho_string;
            $$.literal = $1.literal;
            $$.cases = $1.cases;
            $$.default_label = $1.default_label;
            $$.label_final_switch = $1.label_final_switch;
            $$.label_tamanho_runtime = $1.label_tamanho_runtime;
        }
        ;

POSTFIX_E : POSTFIX_E TK_MAIS_MAIS // precisa desse postfix se nao fica ambiguo
            {
                if ($1.tipo != "int" && $1.tipo != "float") {
                    yyerror("Erro Semantico: O operador '++' so pode ser aplicado a variaveis do tipo int ou float.");
                    $$.tipo = "error";
                } else {
                    string temp_original_val = gentempcode();
                    declaracoes_temp[temp_original_val] = $1.tipo;
                    $$ = $1;
                    $$.traducao = $1.traducao;
                    $$.traducao += "\t" + temp_original_val + " = " + $1.label + ";\n";
                    $$.traducao += "\t" + $1.label + " = " + $1.label + " + 1;\n";
                    $$.label = temp_original_val;
                    $$.tipo = $1.tipo;
                }
            }
          | POSTFIX_E TK_MENOS_MENOS
            {
                if ($1.tipo != "int" && $1.tipo != "float") {
                    yyerror("Erro Semantico: O operador '--' so pode ser aplicado a variaveis do tipo int ou float.");
                    $$.tipo = "error";
                } else {
                    string temp_original_val = gentempcode();
                    declaracoes_temp[temp_original_val] = $1.tipo;
                    $$ = $1;
                    $$.traducao = $1.traducao;
                    $$.traducao += "\t" + temp_original_val + " = " + $1.label + ";\n";
                    $$.traducao += "\t" + $1.label + " = " + $1.label + " - 1;\n";
                    $$.label = temp_original_val;
                    $$.tipo = $1.tipo;
                }
            }
          | '(' E ')' { $$ = $2; }
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
                    $$.traducao = $4.traducao + "\t" + $$.label + " = (" + mapa_tipos_linguagem_para_c.at(destino) + ") " + $4.label + ";\n";
                }
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
                    $$.literal = false;
                    $$.tamanho_string = simb_ptr->tamanho_string;
                    $$.label_tamanho_runtime = simb_ptr->label_tamanho_runtime;
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
          | TK_STRING
            {
               $$ = $1;
               $$.literal = true;
               $$.tamanho_string = $1.tamanho_string;
               $$.traducao = "";
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