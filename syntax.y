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
    // Se o comando gerou código executável no escopo global,
    // guarde-o no buffer em vez de imprimir agora.
    if (!$1.traducao.empty()) {
        codigo_global_executavel += $1.traducao;
    }
    // Retorne uma tradução vazia para não ser impressa prematuramente.
    $$.traducao = "";
}
| TK_TIPO_INT TK_MAIN '(' ')' BLOCO
{
    // Gera as declarações para o escopo global (ex: int v1;)
    string declaracoes_globais = gerar_declaracoes_escopo_atual();

    string codigo;
    codigo += declaracoes_globais;
    codigo += "\nint main(void)\n{\n";
    codigo += codigo_global_executavel;
    
    // Injeta o código executável global (ex: v1 = 1;) no início da main
    
    // Adiciona o conteúdo do bloco da main
    codigo += $5.traducao; 
    
    codigo += "}\n";
    
    $$.traducao = codigo;
}

BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
{
    string codigo_comandos = $3.traducao;
    string codigo_limpeza = gerar_codigo_limpeza_escopo();
    string declaracoes = gerar_declaracoes_escopo_atual();
    
    // Retorna apenas o conteúdo, sem as chaves
    $$.traducao = declaracoes + codigo_comandos + codigo_limpeza;
    
    sair_escopo();
};

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
        $$.tipo = "error";
    } else {
        string c_var_name = simb_ptr->label;
        string var_tipo = simb_ptr->tipo;

        if (var_tipo == "string") {
            simb_ptr->tamanho_string = -1;
            simb_ptr->label_tamanho_runtime = "";

            string len_temp = gentempcode();      declarar_simbolo(len_temp, "int", len_temp);
            string cap_temp = gentempcode();      declarar_simbolo(cap_temp, "int", cap_temp);
            string char_in_temp = gentempcode();    declarar_simbolo(char_in_temp, "char", char_in_temp);
            string scanf_ret_temp = gentempcode();  declarar_simbolo(scanf_ret_temp, "int", scanf_ret_temp);
            string ptr_dest_temp = gentempcode();   declarar_simbolo(ptr_dest_temp, "string", ptr_dest_temp);
            string cond_temp = gentempcode();       declarar_simbolo(cond_temp, "int", cond_temp);
            string cap_limit_temp = gentempcode();  declarar_simbolo(cap_limit_temp, "int", cap_limit_temp);
            string free_cond_temp = gentempcode();    declarar_simbolo(free_cond_temp, "int", free_cond_temp);

            string L_loop_start = genlabel();
            string L_fim_loop = genlabel();
            string L_skip_realloc = genlabel();
            string L_skip_free = genlabel();

            string codigo_gerado;
            codigo_gerado += "\t" + free_cond_temp + " = " + c_var_name + " == NULL;\n";
            codigo_gerado += "\tif (" + free_cond_temp + ") goto " + L_skip_free + ";\n";
            codigo_gerado += "\tfree(" + c_var_name + ");\n";
            codigo_gerado += place_label("\t" + L_skip_free);
            
            codigo_gerado += "\t" + len_temp + " = 0;\n";
            codigo_gerado += "\t" + cap_temp + " = 32;\n";
            codigo_gerado += "\t" + c_var_name + " = (char*) malloc(" + cap_temp + ");\n";
            
            codigo_gerado += place_label("\t" + L_loop_start);
            codigo_gerado += "\t\t" + scanf_ret_temp + " = scanf(\"%c\", &" + char_in_temp + ");\n";
            codigo_gerado += "\t\t" + cond_temp + " = " + scanf_ret_temp + " != 1;\n";
            codigo_gerado += "\t\tif (" + cond_temp + ") goto " + L_fim_loop + ";\n";
            codigo_gerado += "\t\t" + cond_temp + " = " + char_in_temp + " == '\\n';\n";
            codigo_gerado += "\t\tif (" + cond_temp + ") goto " + L_fim_loop + ";\n";
            codigo_gerado += "\t\t" + cap_limit_temp + " = " + cap_temp + " - 1;\n";
            codigo_gerado += "\t\t" + cond_temp + " = " + len_temp + " >= " + cap_limit_temp + ";\n";
            codigo_gerado += "\t\tif (!" + cond_temp + ") goto " + L_skip_realloc + ";\n";
            codigo_gerado += "\t\t\t" + cap_temp + " = " + cap_temp + " * 2;\n";
            codigo_gerado += "\t\t\t" + c_var_name + " = (char*) realloc(" + c_var_name + ", " + cap_temp + ");\n";
            codigo_gerado += place_label("\t\t" + L_skip_realloc);
            codigo_gerado += "\t\t" + ptr_dest_temp + " = " + c_var_name + " + " + len_temp + ";\n";
            codigo_gerado += "\t\t*" + ptr_dest_temp + " = " + char_in_temp + ";\n";
            codigo_gerado += "\t\t" + len_temp + " = " + len_temp + " + 1;\n";
            codigo_gerado += "\t\tgoto " + L_loop_start + ";\n";
            codigo_gerado += place_label("\t" + L_fim_loop);
            codigo_gerado += "\t\t" + ptr_dest_temp + " = " + c_var_name + " + " + len_temp + ";\n";
            codigo_gerado += "\t\t*" + ptr_dest_temp + " = '\\0';\n";

            $$.traducao = codigo_gerado;

        } else if (var_tipo == "boolean") {
            string temp_int_scanf = gentempcode();
            declarar_simbolo(temp_int_scanf, "int", temp_int_scanf);
            string temp_condicao = gentempcode();
            declarar_simbolo(temp_condicao, "boolean", temp_condicao);

            string label_set_zero = genlabel();
            string label_end = genlabel();
            
            string codigo_gerado;
            codigo_gerado += "\tscanf(\"%d\", &" + temp_int_scanf + ");\n";
            codigo_gerado += "\t" + temp_condicao + " = " + temp_int_scanf + " == 0;\n";
            codigo_gerado += "\tif (" + temp_condicao + ") goto " + label_set_zero + ";\n";
            codigo_gerado += "\t" + c_var_name + " = 1;\n";
            codigo_gerado += "\tgoto " + label_end + ";\n"; 
            codigo_gerado += place_label("\t" + label_set_zero);
            codigo_gerado += "\t" + c_var_name + " = 0;\n";
            codigo_gerado += place_label("\t" + label_end);

            $$.traducao = codigo_gerado;

        } else {
            string format_specifier = "";
            if (var_tipo == "int") format_specifier = "%d";
            else if (var_tipo == "float") format_specifier = "%f";
            else if (var_tipo == "char") format_specifier = " %c"; 
            else yyerror("Erro: Tipo '" + var_tipo + "' inválido para leitura.");
            
            if (!format_specifier.empty()) {
                $$.traducao = "\tscanf(\"" + format_specifier + "\", &" + c_var_name + ");\n";
            }
        }
    }
}
    | TK_BREAK ';'
    {
        if (pilha_loops.empty()) {
            yyerror("Erro: 'break' fora de um loop ou switch.");
        } else {
            string label_fim_loop = pilha_loops.back().first;
            $$.traducao = "\tgoto " + label_fim_loop + ";\n";
        }
    }
    |TK_CONTINUE ';'
    {
        if (pilha_loops.empty() || pilha_loops.back().second.empty()) {
            yyerror("Erro: 'continue' fora de um loop apropriado.");
        } else {
            string label_inicio_loop = pilha_loops.back().second;
            $$.traducao = "\tgoto " + label_inicio_loop + ";\n";
        }
    }
    | TK_IF '(' E ')' BLOCO
    {
        string label_fim = genlabel();
        $$.traducao = $3.traducao;
        string temp_cond = gentempcode();
        declarar_simbolo(temp_cond, "int", temp_cond);
        $$.traducao += "\t" + temp_cond + " = !" + $3.label + ";\n";
        $$.traducao += "\tif (" + temp_cond + ") goto " + label_fim + ";\n";
        $$.traducao += $5.traducao; 
        $$.traducao += place_label(label_fim);     
    } 
    | TK_IF '(' E ')' BLOCO TK_ELSE BLOCO
    {
        string label_else = genlabel();
        string label_fim = genlabel();
        $$.traducao = $3.traducao;
        string temp_cond = gentempcode();
        declarar_simbolo(temp_cond, "int", temp_cond);
        $$.traducao += "\t" + temp_cond + " = !" + $3.label + ";\n";
        $$.traducao += "\tif (" + temp_cond + ") goto " + label_else + ";\n";
        $$.traducao += $5.traducao; 
        $$.traducao += "\tgoto " + label_fim + ";\n";
        $$.traducao += place_label(label_else); 
        $$.traducao += $7.traducao; 
        $$.traducao += place_label(label_fim);      
    }
    | TK_WHILE '(' E ')' M_WHILE_SETUP BLOCO 
    {
        // Neste ponto, os labels já foram empilhados pela ação de M_WHILE_SETUP
        // e o BLOCO já foi analisado corretamente.
        
        // Recupera os labels que M_WHILE_SETUP gerou
        string label_inicio = $5.label;
        string label_fim = $5.traducao;

        // Monta o código final na ordem correta
        $$.traducao = place_label(label_inicio);
        $$.traducao += $3.traducao; // Código da condição
        
        string temp_cond = gentempcode();
        declarar_simbolo(temp_cond, "int", temp_cond);
        $$.traducao += "\t" + temp_cond + " = !" + $3.label + ";\n";
        $$.traducao += "\tif (" + temp_cond + ") goto " + label_fim + ";\n";
        
        $$.traducao += $6.traducao; // Código do corpo do loop
        $$.traducao += "\tgoto " + label_inicio + ";\n";
        $$.traducao += place_label(label_fim);

        // Remove os labels da pilha ao final
        pilha_loops.pop_back();
    }
    | TK_DO M_DO_SETUP BLOCO TK_WHILE '(' E ')' ';'
    {
        // Recupera os labels do marcador
        string label_inicio_bloco = $2.label;
        string label_fim_loop = $2.traducao;

        $$.traducao = place_label(label_inicio_bloco);
        $$.traducao += $3.traducao; // Corpo do loop
        $$.traducao += $6.traducao; // Código da condição
        $$.traducao += "\tif (" + $6.label + ") goto " + label_inicio_bloco + ";\n";
        $$.traducao += place_label(label_fim_loop);

        pilha_loops.pop_back();
    }
   | TK_FOR '(' { entrar_escopo(); } COD ';' E ';' M_FOR_SETUP COD ')' BLOCO 
{ 
    // Recupera os labels do marcador que já executou
    string label_continue = $8.label;
    string label_break = $8.traducao;
    string label_condicao = genlabel(); 

    // Monta todo o código executável do loop primeiro
    string codigo_executavel;
    codigo_executavel += $4.traducao; // Inicialização
    codigo_executavel += place_label(label_condicao);
    codigo_executavel += $6.traducao; // Condição
    
    string temp_cond = gentempcode();
    // A declaração de temp_cond será gerada no passo seguinte
    declarar_simbolo(temp_cond, "int", temp_cond); 
    codigo_executavel += "\t" + temp_cond + " = !" + $6.label + ";\n";
    codigo_executavel += "\tif (" + temp_cond + ") goto " + label_break + ";\n";
    
    codigo_executavel += $11.traducao; // Corpo do loop
    codigo_executavel += place_label(label_continue);
    codigo_executavel += $9.traducao;  // Incremento
    codigo_executavel += "\tgoto " + label_condicao + ";\n";
    codigo_executavel += place_label(label_break);
    
    // Agora que todo o código foi gerado e todos os temporários foram
    // registrados, gere as declarações para este escopo.
    string declaracoes = gerar_declaracoes_escopo_atual();
    string limpeza = gerar_codigo_limpeza_escopo();

    // Monta o bloco C final, com declarações no topo.
    $$.traducao = "{\n"
                  + declaracoes
                  + codigo_executavel
                  + limpeza
                  + "}\n";
    
    pilha_loops.pop_back();
    sair_escopo();
}
    | BLOCO { $$ = $1; }
    | SWITCH_STMT { $$ = $1; }
    ;

M_WHILE_SETUP : 
{
    $$.label = genlabel();      
    $$.traducao = genlabel();   
    pilha_loops.push_back(make_pair($$.traducao, $$.label));
}
;
M_FOR_SETUP : 
{
    $$.label = genlabel();      
    $$.traducao = genlabel();   
    pilha_loops.push_back(make_pair($$.traducao, $$.label));
}
;
M_DO_SETUP : 
{
    $$.label = genlabel();      
    $$.traducao = genlabel();   
    pilha_loops.push_back(make_pair($$.traducao, $$.label));
}
;

SWITCH_STMT : TK_SWITCH '(' E ')' 
    {
        string label_fim_switch = genlabel();
        pilha_loops.push_back(make_pair(label_fim_switch, ""));

        if ($3.tipo != "int" && $3.tipo != "char") {
            yyerror("Erro Semantico: Expressao do switch deve ser 'int' ou 'char'.");
        }
        $$ = $3;
        $$.label_final_switch = label_fim_switch;
    }
    '{' { entrar_escopo(); } LISTA_CASES '}'
    {
        atributos expr = $5;
        atributos cases = $8; 
        string label_fim_switch = expr.label_final_switch;

        string codigo_setup;
        codigo_setup += expr.traducao;

        for (const auto& case_info : cases.cases) {
            string comp_temp = gentempcode();
            declarar_simbolo(comp_temp, "boolean", comp_temp);
            codigo_setup += "\t" + comp_temp + " = " + expr.label + " == " + case_info.valor + ";\n";
            codigo_setup += "\tif (" + comp_temp + ") goto " + case_info.label + ";\n";
        }

        if (!cases.default_label.empty()) {
            codigo_setup += "\tgoto " + cases.default_label + ";\n";
        } else {
            codigo_setup += "\tgoto " + label_fim_switch + ";\n";
        }

        string declaracoes_internas = gerar_declaracoes_escopo_atual();
        string codigo_limpeza = gerar_codigo_limpeza_escopo();
        $$.traducao = "{\n"
                      + declaracoes_internas
                      + codigo_setup
                      + cases.traducao
                      + codigo_limpeza 
                      + place_label(label_fim_switch)
                      + "}\n";

        pilha_loops.pop_back();
        sair_escopo();
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
    | { $$.traducao = ""; }
    ;

CASE_STMT : TK_CASE VALOR_LITERAL ':' COMANDOS
    {
        string case_label = genlabel();
        CaseInfo info;
        info.valor = $2.label;
        info.tipo = $2.tipo;
        info.label = case_label;
        $$.cases.push_back(info);
        $$.traducao = place_label(case_label) + $4.traducao;
    }
    | TK_DEFAULT ':' COMANDOS
    {
        if (!$$.default_label.empty()) {
             yyerror("Erro Semantico: Bloco 'default' ja foi definido.");
        }
        $$.default_label = genlabel();
        $$.traducao = place_label($$.default_label) + $3.traducao;
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

COD : DECLARACAO { $$ = $1; }
    | E { $$.traducao = $1.traducao; }
    ;

DECLARACAO : TIPO TK_ID
    {
        string original_name = $2.label;
        // Usa a nova função para gerar um nome sequencial (v1, v2, etc.)
        string c_code_name = genvarname(); 
        
        declarar_simbolo(original_name, $1.tipo, c_code_name);
        mapa_c_para_original[c_code_name] = original_name;
        
        $$.traducao = "";
    }
| TIPO TK_ID '=' E 
{
    string original_name = $2.label;
    // Usa a nova função para gerar um nome sequencial (v1, v2, etc.)
    string c_code_name = genvarname();

    declarar_simbolo(original_name, $1.tipo, c_code_name);
    mapa_c_para_original[c_code_name] = original_name;
    
    if ($1.tipo == "string") {
        if ($4.tipo != "string") {
            yyerror("Erro Semantico: tipo incompatível na atribuição.");
        } else {
            $$.traducao = contar_string(c_code_name, $4);
            atualizar_info_string_simbolo(original_name, $4);
        }
    } else {
        atributos valor_para_atribuir = $4;
        if ($1.tipo != valor_para_atribuir.tipo) {
            valor_para_atribuir = converter_implicitamente(valor_para_atribuir, $1.tipo);
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

E : E '+' E           { $$ = criar_expressao_binaria($1, "+", "+", $3); }
  | E '-' E           { $$ = criar_expressao_binaria($1, "-", "-", $3); }
  | E '*' E           { $$ = criar_expressao_binaria($1, "*", "*", $3); }
  | E '/' E           { $$ = criar_expressao_binaria($1, "/", "/", $3); }
  | E '<' E           { $$ = criar_expressao_binaria($1, "<", "<", $3); }
  | E '>' E           { $$ = criar_expressao_binaria($1, ">", ">", $3); }
  | E '&' E           { $$ = criar_expressao_binaria($1, "&", "&&", $3); }
  | E '|' E           { $$ = criar_expressao_binaria($1, "|", "||", $3); }
  | E TK_MAIOR_IGUAL E { $$ = criar_expressao_binaria($1, ">=", ">=", $3); }
  | E TK_MENOR_IGUAL E { $$ = criar_expressao_binaria($1, "<=", "<=", $3); }
  | E TK_DIFERENTE E   { $$ = criar_expressao_binaria($1, "!=", "!=", $3); }
  | E TK_IGUAL_IGUAL E { $$ = criar_expressao_binaria($1, "==", "==", $3); }
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
                    yyerror("Erro Semantico: tipos incompatíveis.");
                    $$.tipo = "error";
                } else {
                    $$.traducao = rhs.traducao;

                    string temp_cond = gentempcode();
                    declarar_simbolo(temp_cond, "int", temp_cond);
                    string label_skip_free = genlabel();
                    $$.traducao += "\t" + temp_cond + " = " + simb.label + " == NULL;\n";
                    $$.traducao += "\tif (" + temp_cond + ") goto " + label_skip_free + ";\n";
                    $$.traducao += "\tfree(" + simb.label + ");\n";
                    $$.traducao += place_label(label_skip_free);
                    
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
  | UNARY_E { $$ = $1; }
  ;

UNARY_E : TK_MAIS_MAIS UNARY_E   { $$ = criar_expressao_unaria($2, "+"); }
        | TK_MENOS_MENOS UNARY_E  { $$ = criar_expressao_unaria($2, "-"); } 
        | '~' UNARY_E             { $$ = criar_expressao_unaria($2, "~"); }
        | POSTFIX_E               { $$ = $1; }
        ;

POSTFIX_E : POSTFIX_E TK_MAIS_MAIS
            {
                if ($1.tipo != "int" && $1.tipo != "float") {
                    yyerror("Erro Semantico: O operador '++' so pode ser aplicado a variaveis do tipo int ou float.");
                    $$.tipo = "error";
                } else {
                    string temp_original_val = gentempcode();
                    declarar_simbolo(temp_original_val, $1.tipo, temp_original_val);
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
                    declarar_simbolo(temp_original_val, $1.tipo, temp_original_val);
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
                    yyerror("Conversao explicita entre tipos incompatíveis.");
                    $$.tipo = "error";
                } else if (origem == destino) {
                    $$ = $4;
                } else {
                    string temp_name = gentempcode();
                    declarar_simbolo(temp_name, destino, temp_name);
                    $$.label = temp_name;
                    $$.tipo = destino;
                    $$.traducao = $4.traducao + "\t" + $$.label + " = (" + mapa_tipos_linguagem_para_c.at(destino) + ") " + $4.label + ";\n";
                }
            }
          | TK_ID
            {
                atributos* simb_ptr = buscar_simbolo($1.label);
                if (!simb_ptr) {
                    yyerror("Erro Semantico: variavel '" + $1.label + "' nao declarada.");
                    $$.tipo = "error";
                } else {
                    $$ = *simb_ptr;
                    $$.traducao = "";
                }
            }
          | TK_NUM
            {
                string temp_name = gentempcode();
                declarar_simbolo(temp_name, "int", temp_name);
                $$.label = temp_name;
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "int";
            }
          | TK_FLOAT
            {
                string temp_name = gentempcode();
                declarar_simbolo(temp_name, "float", temp_name);
                $$.label = temp_name;
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "float";
            }
          | TK_CHAR
            {
                string temp_name = gentempcode();
                declarar_simbolo(temp_name, "char", temp_name);
                $$.label = temp_name;
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "char";
            }
          | TK_STRING
            {
                $$ = $1;
                $$.literal = true;
                $$.is_temporary = false;
                $$.tamanho_string = $1.tamanho_string;
                $$.traducao = "";
            }
          | TK_TRUE
            {
                string temp_name = gentempcode();
                declarar_simbolo(temp_name, "boolean", temp_name);
                $$.label = temp_name;
                $$.traducao = "\t" + $$.label + " = 1;\n";
                $$.tipo = "boolean";
            }
          | TK_FALSE
            {
                string temp_name = gentempcode();
                declarar_simbolo(temp_name, "boolean", temp_name);
                $$.label = temp_name;
                $$.traducao = "\t" + $$.label + " = 0;\n";
                $$.tipo = "boolean";
            }
          ;

%%

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "lex.yy.c"

string gentempcode()
{
    return "t" + to_string(++var_temp_qnt);
}

string genvarname() {
    return "v" + to_string(++user_var_qnt);
}

int main(int argc, char* argv[])
{
    user_var_qnt = 0;
    var_temp_qnt = 0;
    pilha_tabelas_simbolos.clear();
    mapa_c_para_original.clear();
    entrar_escopo();
    yyparse();
    sair_escopo();
    return 0;
}

void yyerror(string MSG)
{
    cout << "Erro na linha " << contador_linha << ": " << MSG << endl;
    exit(1);
}