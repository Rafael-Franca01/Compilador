%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>
#include "lib.hpp"

string codigo_funcoes_globais;

%}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

%token TK_MENOR_IGUAL TK_MAIOR_IGUAL TK_IGUAL_IGUAL TK_DIFERENTE
%token TK_NUM TK_FLOAT TK_TRUE TK_FALSE TK_CHAR TK_STRING
%token TK_MAIN TK_IF TK_ELSE TK_WHILE TK_FOR TK_DO TK_PRINT TK_SCANF TK_BREAK TK_CONTINUE
%token TK_SWITCH TK_CASE TK_DEFAULT TK_CLASS TK_PONTO
%token TK_TIPO_INT TK_TIPO_FLOAT TK_TIPO_CHAR TK_TIPO_BOOL TK_TIPO_STRING TK_ID TK_MAIS_MAIS TK_MENOS_MENOS
%token TK_TIPO_VOID TK_RETURN
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

        cout << includes << codigo_funcoes_auxiliares << codigo_funcoes_globais << $1.traducao << endl;
    }
    ;

SEXO : LISTA_DEFS_GLOBAIS
    { $$ = $1; }
    ;

LISTA_DEFS_GLOBAIS : DEF_GLOBAL LISTA_DEFS_GLOBAIS
    {
        if ($1.kind == "function_definition") {
            $$.traducao = $2.traducao;
        } else {
            $$.traducao = $1.traducao + $2.traducao;
        }
    }
    | /* vazio */ { $$.traducao = ""; }
    ;

DEF_GLOBAL : DEFINICAO_FUNCAO { $$ = $1; }
           | DEFINICAO_MAIN  { $$ = $1; }
           | DEFINICAO_CLASSE { $$ = $1; } // NOVA OPÇÃO
           ;

DEFINICAO_CLASSE : TK_CLASS TK_ID '{'
                   { estamos_definindo_classe = true; }
                   LISTA_MEMBROS
               '}'
                   { estamos_definindo_classe = false; }
               ';'
               {
    string nome_classe = $2.label;
    if (classes_definidas.count(nome_classe)) {
        yyerror("Classe '" + nome_classe + "' ja foi definida.");
    } else {
        ClassInfo nova_classe;
        nova_classe.nome = nome_classe;
        nova_classe.tamanho_total = 0;
        
        string definicao_struct_c = "\nstruct " + nome_classe + " {\n";
        
        // --- INÍCIO DA LÓGICA CORRIGIDA E LIMPA ---
        for (const auto& membro_decl : $5.args) {
            MemberInfo novo_membro;
            novo_membro.nome = membro_decl.nome_original;
            novo_membro.tipo = membro_decl.tipo;
            novo_membro.tipo_base = membro_decl.tipo_base;
            novo_membro.valor_linhas = membro_decl.valor_linhas;
            novo_membro.valor_colunas = membro_decl.valor_colunas;
            
            string declaracao_membro_c;
            int tamanho_membro_bytes = 0;

            // CASO 1: O membro é um vetor
            if (membro_decl.tipo == "vetor") {
                string c_base_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo_base);
                declaracao_membro_c = c_base_type + "* " + novo_membro.nome;
                tamanho_membro_bytes = 8; // Tamanho de um ponteiro

            // CASO 2: O membro é uma matriz
            } else if (membro_decl.tipo == "matriz") {
                string c_base_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo_base);
                declaracao_membro_c = c_base_type + "** " + novo_membro.nome;
                tamanho_membro_bytes = 8; // Tamanho de um ponteiro para ponteiro

            // CASO 3: O membro é de outro tipo (primitivo ou outra classe)
            } else {
                string c_type;
                // Sub-caso 3.1: O tipo é uma classe já definida?
                if (classes_definidas.count(membro_decl.tipo)) {
                    c_type = "struct " + membro_decl.tipo;
                    tamanho_membro_bytes = classes_definidas.at(membro_decl.tipo).tamanho_total;
                
                // Sub-caso 3.2: O tipo é um primitivo conhecido?
                } else if (mapa_tipos_linguagem_para_c.count(membro_decl.tipo)) {
                    c_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo);
                    tamanho_membro_bytes = mapa_tamanhos_tipos.at(membro_decl.tipo);
                
                // Sub-caso 3.3: É um tipo desconhecido
                } else {
                    yyerror("Tipo desconhecido '" + membro_decl.tipo + "' para o membro '" + novo_membro.nome + "'.");
                    continue; // Pula para o próximo membro do loop
                }
                declaracao_membro_c = c_type + " " + novo_membro.nome;
            }

            // Ações comuns a todos os tipos de membro
            novo_membro.offset = nova_classe.tamanho_total;
            nova_classe.membros.push_back(novo_membro);
            definicao_struct_c += "\t" + declaracao_membro_c + ";\n";
            nova_classe.tamanho_total += tamanho_membro_bytes;
        }
        // --- FIM DA LÓGICA CORRIGIDA E LIMPA ---
        
        definicao_struct_c += "};\n";

        classes_definidas[nome_classe] = nova_classe;
        codigo_funcoes_globais += definicao_struct_c;
    }
    
    $$.kind = "class_definition";
    $$.traducao = "";
}

LISTA_MEMBROS : DECLARACAO ';' LISTA_MEMBROS
              {
                  // Começa com a lista de membros de $2 e adiciona $1 no início
                  $$ = $3;
                  $$.args.insert($$.args.begin(), $1);
              }
              | /* vazio */ { $$.args.clear(); }
              ;


DEFINICAO_MAIN : TK_TIPO_INT TK_MAIN '(' ')' 
    { entrar_escopo(); } // Entra no escopo da main
    '{' COMANDOS '}'
    {
        // 1. Pega o corpo de código gerado para os comandos da main.
        string codigo_comandos = $7.traducao;
        
        // 2. Gera o código de liberação. Isso adiciona os temporários
        //    necessários (t164, etc.) à lista de declarações do escopo atual.
        string codigo_liberacao = gerar_codigo_de_liberacao();
        
        // 3. AGORA, gera TODAS as declarações para o escopo da main.
        //    Isso incluirá as variáveis do corpo E as dos laços de free.
        string codigo_declaracoes = gerar_codigo_declaracoes();
        
        // 4. Sai do escopo da main, pois já coletamos tudo que precisávamos.
        sair_escopo();

        // 5. Monta a string final da função main na ordem correta.
        string codigo_final;
        codigo_final += "int main(void) {\n";
        codigo_final += codigo_declaracoes;  // Bloco de declarações no topo
        codigo_final += codigo_comandos;     // Corpo da função
        codigo_final += codigo_liberacao;    // Código de liberação no final
        codigo_final += "\treturn 0;\n}\n";
        
        $$.traducao = codigo_final;
        $$.kind = "main_definition";
    }
;

DEFINICAO_FUNCAO : TIPO_FUNCAO TK_ID '(' PARAMS ')'
    {
        // Parte 1: Preparar os atributos da função e declará-la no escopo global
        $$.nome_original = $2.label;
        $$.label = $2.label;
        $$.tipo = $1.tipo;
        $$.kind = "function";
        $$.params = $4.params;

        if (!declarar_simbolo($$.nome_original, $$.tipo, $$.label)) { /*...*/ }
        *buscar_simbolo($$.nome_original) = $$;
        
        // Parte 2: Criar o escopo da função
        entrar_escopo();
        pilha_funcoes_atuais.push($$);

        string params_c_code;
        for (size_t i = 0; i < $$.params.size(); ++i) {
            ParamInfo* p = &($$.params[i]);
            
            // Gerar nome único para o parâmetro no código C
            p->nome_no_c = genuniquename();
            
            // --- LÓGICA DE DECLARAÇÃO DO PARÂMETRO (Simplificada e Corrigida) ---
            // 1. Criar um 'atributos' completo para o símbolo do parâmetro
            atributos param_symbol;
            param_symbol.tipo = p->tipo;
            param_symbol.tipo_base = p->tipo_base; // Estará vazio para tipos simples
            param_symbol.label = p->nome_no_c;
            param_symbol.nome_original = p->nome_original;
            param_symbol.kind = "variable";
            
            // 2. Adicionar o símbolo do parâmetro diretamente à tabela do escopo atual
            pilha_tabelas_simbolos.back()[p->nome_original] = param_symbol;
            // --- Fim da Lógica Corrigida ---

            // Montar a string da assinatura da função em C
            string c_type;
            if (p->tipo == "vetor") {
                c_type = mapa_tipos_linguagem_para_c.at(p->tipo_base) + "*";
            } else if (p->tipo == "matriz") {
                c_type = mapa_tipos_linguagem_para_c.at(p->tipo_base) + "**";
            } else if (classes_definidas.count(p->tipo)) { // <-- NOVO CHECK
                // Se o tipo do parâmetro é uma classe, o tipo C é 'struct NomeDaClasse'
                c_type = "struct " + p->tipo;
            } else {
                c_type = mapa_tipos_linguagem_para_c.at(p->tipo);
            }
            params_c_code += c_type + " " + p->nome_no_c;
            if (i < $$.params.size() - 1) { params_c_code += ", "; }
        }
        $$.traducao = params_c_code;
    }
    BLOCO
    {
        sair_escopo();
        pilha_funcoes_atuais.pop();
        string tipo_retorno_c;
        if (classes_definidas.count($6.tipo)) { // <-- NOVO CHECK
            tipo_retorno_c = "struct " + $6.tipo;
        } else {
            tipo_retorno_c = mapa_tipos_linguagem_para_c.at($6.tipo);
        }
        string assinatura = tipo_retorno_c + " " + $6.label + "(" + $6.traducao + ")";
        string corpo_funcao_com_vars = $7.traducao;
        codigo_funcoes_globais += "\n" + assinatura + " {\n" + corpo_funcao_com_vars + "}\n\n";
        $$.kind = "function_definition";
        $$.traducao = "";
    }
    ;

TIPO_FUNCAO : TIPO          { $$ = $1; }
            | TK_TIPO_VOID  { $$.tipo = "void"; }
            ;

PARAMS : LISTA_PARAMS { $$ = $1; }
       |              { $$.params.clear(); }
       ;

LISTA_PARAMS : PARAM
                { 
                    // Ação: A lista de parâmetros é simplesmente o primeiro parâmetro.
                    $$ = $1; 
                }
             | LISTA_PARAMS ',' PARAM
                {
                    // Ação: Começa com a lista que já tínhamos ($1)...
                    $$ = $1;
                    // ...e adiciona o novo parâmetro ($3) no final.
                    $$.params.push_back($3.params[0]);
                }
             ;

PARAM : TIPO TK_ID
        {
            $$.params.clear();
            ParamInfo p;
            p.tipo = $1.tipo;
            p.nome_original = $2.label;
            $$.params.push_back(p);
        }
      | TIPO TK_ID '[' ']'
        {
            $$.params.clear();
            ParamInfo p;
            p.tipo = "vetor";
            p.tipo_base = $1.tipo; // Guarda o tipo dos elementos
            p.nome_original = $2.label;
            $$.params.push_back(p);
        }
      | TIPO TK_ID '[' ']' '[' ']'
        {
            $$.params.clear();
            ParamInfo p;
            p.tipo = "matriz";
            p.tipo_base = $1.tipo; // Guarda o tipo dos elementos
            p.nome_original = $2.label;
            $$.params.push_back(p);
        }
      ;

BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
    {
        string codigo_bloco;
        // Gera as declarações do escopo atual (que está no topo da pilha)
        codigo_bloco += gerar_codigo_declaracoes();
        // Adiciona o código executável do bloco.
        codigo_bloco += $3.traducao;

        sair_escopo(); // Sair do escopo remove as listas da pilha automaticamente.
        $$.traducao = codigo_bloco;
    }
    ;

COMANDOS : COMANDO COMANDOS
    { $$.traducao = $1.traducao + $2.traducao; }
    |
    {
        $$.traducao = "";
    }
    ;

COMANDO : COD  FIM_DE_COMANDO  { $$.traducao = $1.traducao + $2.traducao; }
    | TK_PRINT '(' E ')' ';'
    {
        atributos valor_para_imprimir = desreferenciar_se_necessario($3);
        $$.traducao = valor_para_imprimir.traducao;
        $$.traducao += "\tstd::cout << " + valor_para_imprimir.label + ";\n";
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
                simb_ptr->tamanho_string = -1;
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
                    string temp_int_scanf = gentempcode();
                    
                    string temp_condicao = gentempcode();
                    string label_set_zero = genlabel();
                    string label_end = genlabel();
                    
                    
                    declaracoes_temp.top()[temp_int_scanf] = "int";
                    declaracoes_temp.top()[temp_condicao] = "boolean";

                    
                    string codigo_gerado;
                    
                    
                    codigo_gerado += "\tscanf(\"%d\", &" + temp_int_scanf + ");\n";
                    codigo_gerado += "\t" + temp_condicao + " = " + temp_int_scanf + " == 0;\n";
                    codigo_gerado += "\tif (" + temp_condicao + ") goto " + label_set_zero + ";\n";


                    
                    codigo_gerado += "\t" + c_var_name + " = 1;\n";
                    codigo_gerado += "\tgoto " + label_end + ";\n";
                    
                    
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
    | TK_CONTINUE ';'
    {
        if (pilha_loops.empty() || pilha_loops.back().second.empty()) {
            yyerror("Erro: 'cnt' fora de um loop apropriado.");
            $$ = atributos();
        } else {
            string label_inicio_loop = pilha_loops.back().second;
            $$.traducao = "\tgoto " + label_inicio_loop + ";\n";
        }
    }
    | TK_RETURN ';'
    {
        if (pilha_funcoes_atuais.empty()) {
            yyerror("Comando 'rtn' fora de uma função.");
        } else {
            atributos func_atual = pilha_funcoes_atuais.top();
            if (func_atual.tipo != "void") {
                yyerror("Comando 'rtn' sem valor em uma função que retorna '" + func_atual.tipo + "'.");
            }
        }
        $$.traducao = "\treturn;\n";
    }
    | TK_RETURN E ';'
    {
        if (pilha_funcoes_atuais.empty()) {
            yyerror("Comando 'rtn' fora de uma função.");
        } else {
            atributos func_atual = pilha_funcoes_atuais.top();
            atributos valor_retorno = desreferenciar_se_necessario($2);

            if (func_atual.tipo == "void") {
                yyerror("Comando 'rtn' com valor em uma função do tipo 'vd'.");
            } else if (valor_retorno.tipo != func_atual.tipo) {
                 // Permitir conversão implícita de int para float no retorno
                if(func_atual.tipo == "float" && valor_retorno.tipo == "int") {
                   valor_retorno = converter_implicitamente(valor_retorno, "float");
                } else {
                   yyerror("Tipo de retorno incompatível. Esperado '" + func_atual.tipo + "', mas recebido '" + valor_retorno.tipo + "'.");
                }
            }
            $$.traducao = valor_retorno.traducao + "\treturn " + valor_retorno.label + ";\n";
        }
    }
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
        string label_fim_for = current_loop_labels.first;
        string label_continue_for = current_loop_labels.second;

        string label_condicao_for = genlabel();
        $$.traducao = $4.traducao;
        $$.traducao += label_condicao_for + ":\n";
        $$.traducao += $8.traducao;
        $$.traducao += "\tif (!" + $8.label + ") goto " + label_fim_for + ";\n";
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
    | SWITCH_STMT { $$ = $1; }
    ;

FIM_DE_COMANDO
    : ';'
    {
        $$.traducao = "";
        for (const auto& temp_var : strings_a_liberar_no_comando) {
            $$.traducao += "\tfree(" + temp_var + ");\n";
        }
        strings_a_liberar_no_comando.clear();
    }

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
                    declaracoes_temp.top()[literal_temp] = case_info.tipo;

                    codigo += "\t" + literal_temp + " = " + case_info.valor + ";\n";
                    
                    string comp_temp = gentempcode();
                    declaracoes_temp.top()[comp_temp] = "boolean";

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

DECLARACAO
    : TIPO TK_ID
    {
        if (estamos_definindo_classe) {
            $$.nome_original = $2.label;
            $$.tipo = $1.tipo;
            $$.tipo_base = "";
            $$.traducao = "";
        } else {
            string original_name = $2.label;
            string c_code_name = gentempcode();
            $$.label = c_code_name;
            $$.tipo = $1.tipo;
            $$.traducao = "";

            if (declarar_simbolo(original_name, $1.tipo, c_code_name)) {
                string tipo_declaracao_c;
                bool eh_classe = classes_definidas.count($1.tipo);

                if (eh_classe) {
                    tipo_declaracao_c = "struct " + $1.tipo;
                } else {
                    tipo_declaracao_c = $1.tipo;
                }
                
                declaracoes_temp.top()[c_code_name] = tipo_declaracao_c;
                mapa_c_para_original.top()[c_code_name] = original_name;

                if (eh_classe) {
                    auto& classe_info = classes_definidas.at($1.tipo);
                    for (const auto& membro : classe_info.membros) {
                        if (membro.tipo == "vetor") {
                            string c_type_base = mapa_tipos_linguagem_para_c.at(membro.tipo_base);
                            $$.traducao += "\t" + c_code_name + "." + membro.nome + " = (" + c_type_base + "*) malloc(" + to_string(membro.valor_linhas) + " * sizeof(" + c_type_base + "));\n";
                        } else if (membro.tipo == "matriz") {
                             string c_type_base = mapa_tipos_linguagem_para_c.at(membro.tipo_base);
                             string linhas_str = to_string(membro.valor_linhas);
                             string colunas_str = to_string(membro.valor_colunas);

                             $$.traducao += "\t" + c_code_name + "." + membro.nome + " = (" + c_type_base + "**) malloc(" + linhas_str + " * sizeof(" + c_type_base + "*));\n";

                             string loop_var = gentempcode();
                             declaracoes_temp.top()[loop_var] = "int";
                             string loop_start = genlabel();
                             string loop_end = genlabel();
                             string loop_cond = gentempcode();
                             declaracoes_temp.top()[loop_cond] = "boolean";

                             $$.traducao += "\t" + loop_var + " = 0;\n";
                             $$.traducao += loop_start + ":\n";
                             $$.traducao += "\t\t" + loop_cond + " = " + loop_var + " < " + linhas_str + ";\n";
                             $$.traducao += "\t\tif (!" + loop_cond + ") goto " + loop_end + ";\n";
                             $$.traducao += "\t\t" + c_code_name + "." + membro.nome + "[" + loop_var + "] = (" + c_type_base + "*) malloc(" + colunas_str + " * sizeof(" + c_type_base + "));\n";
                             $$.traducao += "\t\t" + loop_var + " = " + loop_var + " + 1;\n";
                             $$.traducao += "\t\tgoto " + loop_start + ";\n";
                             $$.traducao += loop_end + ":\n";
                        }
                    }
                }

                if ($1.tipo == "string") {
                    if (pilha_funcoes_atuais.empty()){
                        strings_a_liberar.push_back(c_code_name);
                    }
                }
            }
        }
    }

    // Alternativa 2: Declaração com atribuição (ex: int x = 10;)
    | TIPO TK_ID '=' E
    {
        if (estamos_definindo_classe) {
            yyerror("Erro: Inicializacao de membros na declaracao de classe nao e suportada.");
            $$ = atributos();
        } else {
            string original_name = $2.label;
            string c_code_name = gentempcode();
            string tipo_declarado = $1.tipo;
            
            $$ = $4;
            $$.label = c_code_name;
            $$.tipo = tipo_declarado;
            $$.nome_original = original_name;

            if (declarar_simbolo(original_name, tipo_declarado, c_code_name)) {
                declaracoes_temp.top()[c_code_name] = tipo_declarado;
                mapa_c_para_original.top()[c_code_name] = original_name;

                if (tipo_declarado == "string") {
                    if ($4.tipo != "string") {
                        yyerror("Erro Semantico: tipo incompativel na atribuicao da declaracao de '" + original_name + "'. Esperado 'string', recebido '" + $4.tipo + "'.");
                    } else {
                        $$.traducao = contar_string(c_code_name, $4);
                        atualizar_info_string_simbolo(original_name, $4);
                        if(pilha_funcoes_atuais.empty()){
                            strings_a_liberar.push_back(c_code_name);
                        }
                    }
                } else {
                    atributos valor_para_atribuir = $4;
                    if (tipo_declarado != valor_para_atribuir.tipo) {
                        if ((tipo_declarado == "float" && valor_para_atribuir.tipo == "int") || (tipo_declarado == "int" && valor_para_atribuir.tipo == "float")) {
                            valor_para_atribuir = converter_implicitamente(valor_para_atribuir, tipo_declarado);
                        } else {
                            yyerror("Erro Semantico: tipo incompativel na atribuicao da declaracao de '" + original_name + "'. Esperado '" + tipo_declarado + "', recebido '" + valor_para_atribuir.tipo + "'.");
                        }
                    }
                    $$.traducao = valor_para_atribuir.traducao;
                    $$.traducao += "\t" + c_code_name + " = " + valor_para_atribuir.label + ";\n";
                }
            }
        }
    }

    // Alternativa 3: Declaração de Vetor (ex: int v[10];)
    | TIPO TK_ID '[' E ']'
    {
        if (estamos_definindo_classe) {
            if (!$4.eh_literal) {
                yyerror("Erro: O tamanho de um vetor membro de classe deve ser uma constante inteira.");
            }
            $$.nome_original = $2.label;
            $$.tipo = "vetor";
            $$.tipo_base = $1.tipo;
            $$.valor_linhas = $4.valor_literal;
            $$.traducao = "";
        } else {
            if ($4.tipo != "int") {
                yyerror("Erro Semantico: O tamanho de um vetor deve ser um inteiro.");
                $$ = atributos();
            } else {
                string original_name = $2.label;
                if (buscar_simbolo(original_name)) {
                    yyerror("Erro Semantico: Variavel '" + original_name + "' ja declarada.");
                    $$ = atributos();
                } else {
                    string c_name = gentempcode();
                    string c_type = mapa_tipos_linguagem_para_c.at($1.tipo);
                    
                    atributos vet_attrs;
                    vet_attrs.label = c_name;
                    vet_attrs.tipo = "vetor";
                    vet_attrs.tipo_base = $1.tipo;
                    vet_attrs.eh_vetor = true;
                    vet_attrs.eh_endereco = false;
                    pilha_tabelas_simbolos.back()[original_name] = vet_attrs;
                    
                    string c_type_base = mapa_tipos_linguagem_para_c.at($1.tipo);
                    declaracoes_temp.top()[c_name] = c_type_base + "*";
                    mapa_c_para_original.top()[c_name] = original_name;

                    $$.traducao = $4.traducao;
                    $$.traducao += "\t" + c_name + " = (" + c_type + "*) malloc(" + $4.label + " * " + "sizeof(" + c_type + ")" + ");\n";
                    
                    strings_a_liberar.push_back(c_name);
                }
            }
        }
    }

    // Alternativa 4: Declaração de Matriz (ex: int m[2][3];)
    | TIPO TK_ID '[' E ']' '[' E ']'
    {
        if (estamos_definindo_classe) {
            if (!$4.eh_literal || !$7.eh_literal) {
                yyerror("Erro: As dimensoes de uma matriz membro de classe devem ser constantes inteiras.");
            }
            $$.nome_original = $2.label;
            $$.tipo = "matriz";
            $$.tipo_base = $1.tipo;
            $$.valor_linhas = $4.valor_literal;
            $$.valor_colunas = $7.valor_literal;
            $$.traducao = "";
        } else {
            if ($4.tipo != "int" || $7.tipo != "int") {
                yyerror("Erro Semantico: As dimensoes de uma matriz devem ser inteiras.");
                $$ = atributos();
            } else {
                string original_name = $2.label;
                if (buscar_simbolo(original_name)) {
                    yyerror("Erro Semantico: Variavel '" + original_name + "' ja declarada.");
                    $$ = atributos();
                } else {
                    string c_type_base = mapa_tipos_linguagem_para_c.at($1.tipo);
                    string c_name = genuniquename();
                    
                    atributos mat_attrs;
                    mat_attrs.label = c_name;
                    mat_attrs.tipo = "matriz";
                    mat_attrs.tipo_base = $1.tipo;
                    mat_attrs.eh_vetor = true;
                    mat_attrs.label_linhas = $4.label;
                    mat_attrs.label_colunas = $7.label;
                    mat_attrs.valor_linhas = $4.eh_literal ? $4.valor_literal : -1;
                    mat_attrs.valor_colunas = $7.eh_literal ? $7.valor_literal : -1;
                    pilha_tabelas_simbolos.back()[original_name] = mat_attrs;
                    
                    string temp_loop_var = genuniquename();
                    string temp_condicao = genuniquename();
                    string label_inicio_loop = genlabel();
                    string label_fim_loop = genlabel();
                    string temp_addr_ptr = genuniquename();
                    string temp_malloc_result = genuniquename();

                    declaracoes_temp.top()[c_name] = c_type_base + "**";
                    mapa_c_para_original.top()[c_name] = original_name;
                    declaracoes_temp.top()[temp_loop_var] = "int";
                    declaracoes_temp.top()[temp_condicao] = "boolean";
                    declaracoes_temp.top()[temp_addr_ptr] = c_type_base + "**";
                    declaracoes_temp.top()[temp_malloc_result] = c_type_base + "*";

                    $$.traducao = $4.traducao + $7.traducao;
                    $$.traducao += "\t" + c_name + " = (" + c_type_base + "**) malloc(" + $4.label + " * sizeof(" + c_type_base + "*));\n";
                    $$.traducao += "\t" + temp_loop_var + " = 0;\n";
                    $$.traducao += label_inicio_loop + ":\n";
                    $$.traducao += "\t\t" + temp_condicao + " = " + temp_loop_var + " < " + $4.label + ";\n";
                    $$.traducao += "\t\tif (!" + temp_condicao + ") goto " + label_fim_loop + ";\n";
                    $$.traducao += "\t\t" + temp_addr_ptr + " = " + c_name + " + " + temp_loop_var + ";\n";
                    $$.traducao += "\t\t" + temp_malloc_result + " = (" + c_type_base + "*) malloc(" + $7.label + " * sizeof(" + c_type_base + "));\n";
                    $$.traducao += "\t\t*" + temp_addr_ptr + " = " + temp_malloc_result + ";\n";
                    $$.traducao += "\t\t" + temp_loop_var + " = " + temp_loop_var + " + 1;\n";
                    $$.traducao += "\t\tgoto " + label_inicio_loop + ";\n";
                    $$.traducao += label_fim_loop + ":\n";

                    matrizes_a_liberar.push_back(make_pair(c_name, $4.label));
                }
            }
        }
    }
;

TIPO : TK_TIPO_INT { $$.tipo = "int"; }
    | TK_TIPO_FLOAT { $$.tipo = "float"; }
    | TK_TIPO_BOOL { $$.tipo = "boolean"; }
    | TK_TIPO_CHAR { $$.tipo = "char"; }
    | TK_TIPO_STRING { $$.tipo = "string"; }
    | TK_ID           {
                           // Verifica se o ID é um tipo de classe que já definimos
                           if (classes_definidas.count($1.label)) {
                               $$.tipo = $1.label; // O tipo é o próprio nome da classe
                           } else {
                               yyerror("Tipo ou classe '" + $1.label + "' nao foi definido.");
                               $$.tipo = "error";
                           }
                       }
     ;

E : POSTFIX_E '=' E
{
    atributos lhs = $1;
    atributos rhs = $3;

    // Caso 1: Atribuição a uma string
    if (lhs.tipo == "string" && lhs.eh_endereco) {
        rhs = desreferenciar_se_necessario(rhs);
        if (rhs.tipo != "string") {
            yyerror("Erro Semantico: tipo incompativel para atribuir a string.");
            $$ = atributos();
        } else {
            // Cria um novo temporário para a string alocada
            string temp_new_str = gentempcode();
            declaracoes_temp.top()[temp_new_str] = "char*"; // O tipo em C é char*
            
            // Gera código para alocar memória e copiar o conteúdo da string
            $$.traducao = contar_string(temp_new_str, rhs); 
            // Adiciona o código para obter o endereço do LHS (ex: de joao.nome)
            $$.traducao += lhs.traducao;
            // Atribui o ponteiro da nova string alocada ao membro da struct
            $$.traducao += "\t*" + lhs.label + " = " + temp_new_str + ";\n";
            
            $$.label = lhs.label; 
            $$.tipo = lhs.tipo;
        }
    } 
    // Caso 2: Outras atribuições (int, float, etc.)
    else { 
        rhs = desreferenciar_se_necessario(rhs);
        if (lhs.tipo != rhs.tipo) {
            if ((lhs.tipo == "float" && rhs.tipo == "int") || (lhs.tipo == "int" && rhs.tipo == "float")) {
                 rhs = converter_implicitamente(rhs, lhs.tipo);
            } else {
                yyerror("Erro Semantico: tipos incompativeis para atribuicao.");
                $$ = atributos();
            }
        }
        $$.traducao = lhs.traducao + rhs.traducao;

        if (lhs.eh_endereco) {
            $$.traducao += "\t*" + lhs.label + " = " + rhs.label + ";\n";
        } else {
            $$.traducao += "\t" + lhs.label + " = " + rhs.label + ";\n";
        }
        $$.label = rhs.label;
        $$.tipo = rhs.tipo;
    }
}
| E '+' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "+", "+", desreferenciar_se_necessario($3)); }
| E '-' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "-", "-", desreferenciar_se_necessario($3)); }
| E '*' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "*", "*", desreferenciar_se_necessario($3)); }
| E '/' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "/", "/", desreferenciar_se_necessario($3)); }
| E '<' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "<", "<", desreferenciar_se_necessario($3)); }
| E '>' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), ">", ">", desreferenciar_se_necessario($3)); }
| E '&' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "&", "&&", desreferenciar_se_necessario($3)); }
| E '|' E              { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "|", "||", desreferenciar_se_necessario($3)); }
| E TK_MAIOR_IGUAL E   { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), ">=", ">=", desreferenciar_se_necessario($3)); }
| E TK_MENOR_IGUAL E   { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "<=", "<=", desreferenciar_se_necessario($3)); }
| E TK_DIFERENTE E     { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "!=", "!=", desreferenciar_se_necessario($3)); }
| E TK_IGUAL_IGUAL E   { $$ = criar_expressao_binaria(desreferenciar_se_necessario($1), "==", "==", desreferenciar_se_necessario($3)); }
| UNARY_E              { $$ = $1; }
;

UNARY_E : TK_MAIS_MAIS UNARY_E  { $$ = criar_expressao_unaria($2, "+"); }
        | TK_MENOS_MENOS UNARY_E { $$ = criar_expressao_unaria($2, "-"); }
        | '~' UNARY_E            { $$ = criar_expressao_unaria($2, "~"); }
        | POSTFIX_E
        {
            $$ = $1;
        }
        ;

POSTFIX_E : POSTFIX_E TK_MAIS_MAIS
            {
                if ($1.tipo != "int" && $1.tipo != "float") {
                    yyerror("Erro Semantico: O operador '++' so pode ser aplicado a variaveis do tipo int ou float.");
                    $$.tipo = "error";
                } else {
                    string temp_original_val = gentempcode();
                    declaracoes_temp.top()[temp_original_val] = $1.tipo;
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
                    declaracoes_temp.top()[temp_original_val] = $1.tipo;
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
                    declaracoes_temp.top()[$$.label] = destino;
                    $$.traducao = $4.traducao + "\t" + $$.label + " = (" + mapa_tipos_linguagem_para_c.at(destino) + ") " + $4.label + ";\n";
                }
            }
          | TK_ID '(' ARGS ')'
            {
                string nome_funcao = $1.label;
                atributos* simb = buscar_simbolo(nome_funcao);

                if (!simb || simb->kind != "function") {
                    yyerror("'" + nome_funcao + "' não é uma função ou não foi declarada.");
                    $$.tipo = "error";
                } else {
                    vector<atributos> args = $3.args;
                    if (args.size() != simb->params.size()) {
                        yyerror("Número incorreto de argumentos para a função '" + nome_funcao + "'. Esperado: " + to_string(simb->params.size()) + ", Recebido: " + to_string(args.size()));
                        $$.tipo = "error";
                    } else {
                        string codigo_args;
                        string c_args_list;

                        for (size_t i = 0; i < args.size(); ++i) {
                            atributos arg = desreferenciar_se_necessario(args[i]);
                            string param_tipo = simb->params[i].tipo;
                            if(arg.tipo != param_tipo && !(param_tipo == "float" && arg.tipo == "int")) {
                                yyerror("Tipo do argumento " + to_string(i+1) + " incompatível na chamada de '" + nome_funcao + "'.");
                            }
                            if (param_tipo == "float" && arg.tipo == "int") {
                                arg = converter_implicitamente(arg, "float");
                            }
                            codigo_args += arg.traducao;
                            c_args_list += arg.label;
                            if (i < args.size() - 1) {
                                c_args_list += ", ";
                            }
                        }

                        $$.traducao = codigo_args;
                        $$.tipo = simb->tipo; // O tipo da expressão é o tipo de retorno da função

                        if ($$.tipo != "void") {
                            $$.label = gentempcode();
                            declaracoes_temp.top()[$$.label] = $$.tipo;
                            $$.traducao += "\t" + $$.label + " = " + nome_funcao + "(" + c_args_list + ");\n";
                            if ($$.tipo == "string") {
                                strings_a_liberar.push_back($$.label);
                            }
                        } else {
                            $$.label = ""; // Chamada de função void não tem valor
                            $$.traducao += "\t" + nome_funcao + "(" + c_args_list + ");\n";
                        }
                    }
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
                }
                
                $$.nome_original = $1.label;
            }
    | POSTFIX_E '[' E ']'
    {
        atributos base = $1;
        atributos indice = desreferenciar_se_necessario($3);

        if ((base.tipo != "vetor" && base.tipo != "matriz") && !(base.eh_endereco)) {
            yyerror("Erro Semantico: Variavel '" + base.nome_original + "' nao e um vetor ou matriz.");
            $$ = atributos();
        } else if (indice.tipo != "int") {
            yyerror("Erro Semantico: Indice de vetor ou matriz deve ser um inteiro.");
            $$ = atributos();
        } else {
            string base_ptr_label = base.label;
            $$.traducao = base.traducao + indice.traducao;

            if (base.eh_endereco) {
                string actual_ptr = gentempcode();
                string c_type_of_actual_ptr;

                if (base.tipo == "vetor") {
                    c_type_of_actual_ptr = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "*";
                } else { // matriz
                    c_type_of_actual_ptr = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "**";
                }
                
                declaracoes_temp.top()[actual_ptr] = c_type_of_actual_ptr;
                $$.traducao += "\t" + actual_ptr + " = *" + base.label + ";\n";
                base_ptr_label = actual_ptr;
            }

            // A linha abaixo usa gentempcode() para criar E REGISTRAR a variável
            // temporária que armazena o endereço do elemento.
            string addr_temp = gentempcode(); 
            string addr_temp_c_type = (base.tipo == "matriz") 
                                    ? (mapa_tipos_linguagem_para_c.at(base.tipo_base) + "**") 
                                    : (mapa_tipos_linguagem_para_c.at(base.tipo_base) + "*");
            declaracoes_temp.top()[addr_temp] = addr_temp_c_type;
            
            $$.traducao += "\t" + addr_temp + " = " + base_ptr_label + " + " + indice.label + ";\n";

            $$.label = addr_temp;
            $$.eh_endereco = true;
            $$.nome_original = base.nome_original;

            if(base.tipo == "matriz") {
                $$.tipo = "vetor";
                $$.tipo_base = base.tipo_base;
            } else if (base.tipo == "vetor") {
                $$.tipo = base.tipo_base;
                $$.tipo_base = "";
            }
        }
    }
| POSTFIX_E TK_PONTO TK_ID
{
    atributos base_obj = $1;
    string nome_membro = $3.label;

    auto it_classe = classes_definidas.find(base_obj.tipo);
    if (it_classe == classes_definidas.end()) {
        yyerror("Erro Semantico: Acesso de membro '.' em algo que nao e uma classe: '" + base_obj.nome_original + "'.");
        $$ = atributos();
    } else {
        auto& classe_info = it_classe->second;
        MemberInfo* membro_info = nullptr;
        for(auto& m : classe_info.membros) { if (m.nome == nome_membro) { membro_info = &m; break; } }

        if (membro_info == nullptr) {
            yyerror("Erro Semantico: Classe '" + base_obj.tipo + "' nao tem um membro chamado '" + nome_membro + "'.");
            $$ = atributos();
        } else {
            $$.traducao = base_obj.traducao;
            $$.nome_original = base_obj.nome_original + "." + nome_membro;
            $$.tipo = membro_info->tipo;
            $$.tipo_base = membro_info->tipo_base;
            $$.valor_linhas = membro_info->valor_linhas;
            $$.valor_colunas = membro_info->valor_colunas;

            if ($$.tipo == "matriz" || $$.tipo == "vetor") {
                string linhas_label = gentempcode();
                declaracoes_temp.top()[linhas_label] = "int";
                $$.traducao += "\t" + linhas_label + " = " + to_string(membro_info->valor_linhas) + ";\n";
                $$.label_linhas = linhas_label;

                if ($$.tipo == "matriz") {
                    string colunas_label = gentempcode();
                    declaracoes_temp.top()[colunas_label] = "int";
                    $$.traducao += "\t" + colunas_label + " = " + to_string(membro_info->valor_colunas) + ";\n";
                    $$.label_colunas = colunas_label;
                }
            }

            string addr_temp = gentempcode();
            string member_c_type;
            
            if (membro_info->tipo == "vetor") {
                member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo_base) + "*";
            } else if (membro_info->tipo == "matriz") {
                member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo_base) + "**";
            } else if (classes_definidas.count(membro_info->tipo)) {
                member_c_type = "struct " + membro_info->tipo;
            } else {
                member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo);
            }

            // --- ESTA É A LÓGICA CORRIGIDA ---
            // O tipo do ponteiro para o membro é sempre "o tipo C do membro" + "*"
            string temp_addr_type = member_c_type + "*";
            declaracoes_temp.top()[addr_temp] = temp_addr_type;
            // --- FIM DA LÓGICA CORRIGIDA ---
            
            if (base_obj.eh_endereco) {
                // Esta parte está correta, mas não é usada neste exemplo
                $$.traducao += "\t" + addr_temp + " = &(" + base_obj.label + "->" + nome_membro + ");\n";
            } else {
                $$.traducao += "\t" + addr_temp + " = &" + base_obj.label + "." + nome_membro + ";\n";
            }

            $$.label = addr_temp;
            $$.eh_endereco = true;
        }
    }
}
          | TK_NUM
            {
                $$.label = gentempcode();
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "int";
                declaracoes_temp.top()[$$.label] = $$.tipo;
                $$.valor_literal = atoi($1.label.c_str());
                $$.eh_literal = true;
            }
          | TK_FLOAT
            {
                $$.label = gentempcode();
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "float";
                declaracoes_temp.top()[$$.label] = $$.tipo;
            }
          | TK_CHAR
            {
                $$.label = gentempcode();
                $$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
                $$.tipo = "char";
                declaracoes_temp.top()[$$.label] = $$.tipo;
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
                declaracoes_temp.top()[$$.label] = $$.tipo;
            }
          | TK_FALSE
            {
                $$.label = gentempcode();
                $$.traducao = "\t" + $$.label + " = 0;\n";
                $$.tipo = "boolean";
                declaracoes_temp.top()[$$.label] = $$.tipo;
            }
            
          ;

ARGS : LISTA_ARGS { $$ = $1; }
     |             { $$.args.clear(); /* Sem argumentos */ }
     ;

LISTA_ARGS : E
            { $$.args.push_back($1); }
           | LISTA_ARGS ',' E
            {
                $$.args = $1.args;
                $$.args.push_back($3);
            }
           ;
%%

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "lex.yy.c"

string gentempcode() {
    string nome = "t" + to_string(++var_temp_qnt);
    ordem_declaracoes.top().push_back(nome);
    return nome;
}

int main(int argc, char* argv[])
{
    var_temp_qnt = 0;

    // Limpa a pilha de tabelas de símbolos (que é um vector, então .clear() funciona)
    pilha_tabelas_simbolos.clear();
    
    // A std::stack não tem .clear(), então limpamos assim para garantir
    while(!ordem_declaracoes.empty()) ordem_declaracoes.pop();
    while(!declaracoes_temp.empty()) declaracoes_temp.pop();
    while(!mapa_c_para_original.empty()) mapa_c_para_original.pop();

    // Cria o escopo global (nível 1) em todas as pilhas
    entrar_escopo();

    // Inicia a análise sintática do código-fonte
    yyparse();

    // Sai do escopo global ao final da compilação
    sair_escopo();

    return 0;
}

void yyerror(string MSG)
{
    cout << "Erro na linha " << contador_linha << ": " << MSG << endl;
    exit(1);
}