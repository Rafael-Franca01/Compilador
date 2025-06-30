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
%token TK_CLASS TK_PONTO
%token TK_SWITCH TK_CASE TK_DEFAULT
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
%right UMINUS
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
		   | DECLARACAO_FUNCAO { $$ = $1; }
		   | DEFINICAO_MAIN  { $$ = $1; }
           | DEFINICAO_CLASSE { $$ = $1; } 
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
		
		for (const auto& membro_decl : $5.args) {
			MemberInfo novo_membro;
			novo_membro.nome = membro_decl.nome_original;
			novo_membro.tipo = membro_decl.tipo;
			novo_membro.tipo_base = membro_decl.tipo_base;
			novo_membro.valor_linhas = membro_decl.valor_linhas;
			novo_membro.valor_colunas = membro_decl.valor_colunas;
			
			string declaracao_membro_c;
			int tamanho_membro_bytes = 0;

			if (membro_decl.tipo == "vetor") {
				string c_base_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo_base);
				declaracao_membro_c = c_base_type + "* " + novo_membro.nome;
				tamanho_membro_bytes = 8;
			} else if (membro_decl.tipo == "matriz") {
				string c_base_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo_base);
				declaracao_membro_c = c_base_type + "** " + novo_membro.nome;
				tamanho_membro_bytes = 8;
			} else {
				string c_type;
				if (classes_definidas.count(membro_decl.tipo)) {
					c_type = "struct " + membro_decl.tipo;
					tamanho_membro_bytes = classes_definidas.at(membro_decl.tipo).tamanho_total;
				} else if (mapa_tipos_linguagem_para_c.count(membro_decl.tipo)) {
					c_type = mapa_tipos_linguagem_para_c.at(membro_decl.tipo);
					tamanho_membro_bytes = mapa_tamanhos_tipos.at(membro_decl.tipo);
				} else {
					yyerror("Tipo desconhecido '" + membro_decl.tipo + "' para o membro '" + novo_membro.nome + "'.");
					continue;
				}
				declaracao_membro_c = c_type + " " + novo_membro.nome;
			}

			novo_membro.offset = nova_classe.tamanho_total;
			nova_classe.membros.push_back(novo_membro);
			definicao_struct_c += "\t" + declaracao_membro_c + ";\n";
			nova_classe.tamanho_total += tamanho_membro_bytes;
		}
		
		definicao_struct_c += "};\n";

		classes_definidas[nome_classe] = nova_classe;
		codigo_funcoes_globais += definicao_struct_c;
	}
	
	$$.kind = "class_definition";
	$$.traducao = "";
}

LISTA_MEMBROS : DECLARACAO ';' LISTA_MEMBROS
				  {
					  $$ = $3;
					  $$.args.insert($$.args.begin(), $1);
				  }
				  | /* vazio */ { $$.args.clear(); }
				  ;

DECLARACAO_FUNCAO : TIPO_FUNCAO TK_ID '(' PARAMS ')' ';'
	{
		string func_name = $2.label;
		atributos* symbol = buscar_simbolo(func_name);
        encontrou_retorno_na_funcao_atual = false;
		// Erro se já existir uma definição completa com o mesmo nome
		if (symbol && symbol->kind == "function") {
			yyerror("Erro: Prototipo para a funcao '" + func_name + "' que ja foi definida.");
		}
		// Se ainda não existir, adiciona o protótipo à tabela de símbolos global
		else if (!symbol) {
			atributos func_attrs;
			func_attrs.nome_original = func_name;
			func_attrs.label = func_name;
			func_attrs.tipo = $1.tipo;
			func_attrs.params = $4.params;
			func_attrs.kind = "function_prototype"; // Marca como protótipo
			pilha_tabelas_simbolos[0][func_name] = func_attrs; // Adiciona ao escopo global
		}
		// Se já existir um protótipo, ignora (uma checagem mais robusta compararia as assinaturas)

		$$.traducao = ""; // Protótipos não geram código executável
		$$.kind = "function_declaration";
	}
	;

DEFINICAO_MAIN : TK_TIPO_INT TK_MAIN '(' ')' MAIN_BLOCO
	{
		string codigo;
		codigo += "int main(void) {\n";
		codigo += $5.traducao;
		codigo += "\treturn 0;\n}\n";
		$$.traducao = codigo;
		$$.kind = "main_definition";
	}
	;
    // mage vai tomar no seu cu
    MAIN_BLOCO : '{' { entrar_escopo(); } COMANDOS '}'
	{
		string codigo_comandos = $3.traducao;
		string codigo_liberacao = gerar_codigo_de_liberacao();
		string codigo_declaracoes = gerar_codigo_declaracoes();
		
		$$.traducao = codigo_declaracoes + codigo_comandos + codigo_liberacao;
		sair_escopo();
	}
	;

DEFINICAO_FUNCAO : TIPO_FUNCAO TK_ID '(' PARAMS ')'
	{
		string func_name = $2.label;
		atributos* symbol = buscar_simbolo(func_name);

		// Erro se a função já estiver completamente definida
		if (symbol && symbol->kind == "function") {
			yyerror("Erro: Redefinicao da funcao '" + func_name + "'.");
		}

		// Se um protótipo já existe, verifica se a definição é compatível
		if (symbol && symbol->kind == "function_prototype") {
			if (symbol->tipo != $1.tipo) {
				yyerror("Erro: Conflito no tipo de retorno para a funcao '" + func_name + "'.");
			}
			if (symbol->params.size() != $4.params.size()) {
				yyerror("Erro: Conflito no numero de parametros para a funcao '" + func_name + "'.");
			}
			// (Opcional) Adicionar checagem de tipo para cada parâmetro
			
			// Atualiza o símbolo existente para uma definição completa
			symbol->kind = "function";
			symbol->params = $4.params;
			$$ = *symbol;
		} else {
			// Nenhum protótipo encontrado, trata como uma definição direta
			$$.nome_original = func_name;
			$$.label = func_name;
			$$.tipo = $1.tipo;
			$$.params = $4.params;
			$$.kind = "function";
			pilha_tabelas_simbolos[0][func_name] = $$; // Adiciona ao escopo global
		}

		// O resto da regra para criar o escopo e processar os parâmetros continua igual
		entrar_escopo();
		pilha_funcoes_atuais.push($$);

		string params_c_code;
		for (size_t i = 0; i < $$.params.size(); ++i) {
			ParamInfo* p = &($$.params[i]);
			p->nome_no_c = genuniquename();
			atributos param_symbol;
			param_symbol.tipo = p->tipo;
			param_symbol.tipo_base = p->tipo_base;
			param_symbol.label = p->nome_no_c;
			param_symbol.nome_original = p->nome_original;
			param_symbol.kind = "variable";
			pilha_tabelas_simbolos.back()[p->nome_original] = param_symbol;
			string c_type;
			if (p->tipo == "vetor") {
				c_type = mapa_tipos_linguagem_para_c.at(p->tipo_base) + "*";
			} else if (p->tipo == "matriz") {
				c_type = mapa_tipos_linguagem_para_c.at(p->tipo_base) + "**";
			} else if  (classes_definidas.count(p->tipo)) {
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
        if ($6.tipo != "void" && !encontrou_retorno_na_funcao_atual) {
			yyerror("Erro Semantico: A funcao '" + $6.nome_original + "' deve retornar um valor.");
		}
		sair_escopo();
		pilha_funcoes_atuais.pop();
        string tipo_retorno_c;
		if (classes_definidas.count($6.tipo)) { 
			tipo_retorno_c = "struct " + $6.tipo;
		} else {
            tipo_retorno_c = mapa_tipos_linguagem_para_c.at($6.tipo);
            string assinatura = tipo_retorno_c + " " + $6.label + "(" + $6.traducao + ")";
            string corpo_funcao_com_vars = $7.traducao;
            codigo_funcoes_globais += "\n" + assinatura + " {\n" + corpo_funcao_com_vars + "}\n\n";
            $$.kind = "function_definition";
            $$.traducao = "";
        }
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
		string codigo_declaracoes = gerar_codigo_declaracoes();
		$$.traducao = codigo_declaracoes + $3.traducao;
		sair_escopo();
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
            yyerror("Comando 'rtn' fora de uma função ou presente na main.");
        } else {
            atributos func_atual = pilha_funcoes_atuais.top();
            if (func_atual.tipo != "void") {
                yyerror("Comando 'rtn' sem valor em uma função que retorna '" + func_atual.tipo + "'.");
            }
        }
        encontrou_retorno_na_funcao_atual = true;
        $$.traducao = "\treturn;\n";
    }
    | TK_RETURN E ';'
    {
        if (pilha_funcoes_atuais.empty()) {
            yyerror("Comando 'rtn' fora de uma função ou presente na main.");
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
        encontrou_retorno_na_funcao_atual = true;
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

		string codigo_executavel;
		codigo_executavel += $4.traducao;
		codigo_executavel += label_condicao_for + ":\n";
		codigo_executavel += $8.traducao;
		codigo_executavel += "\tif (!" + $8.label + ") goto " + label_fim_for + ";\n";
		codigo_executavel += $11.traducao;
		codigo_executavel += label_continue_for + ":\n";
		codigo_executavel += $9.traducao;
		codigo_executavel += "\tgoto " + label_condicao_for + ";\n";
		codigo_executavel += label_fim_for + ":\n";

		string codigo_declaracoes = gerar_codigo_declaracoes();
		
		$$.traducao = codigo_declaracoes + codigo_executavel;

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

DECLARACAO : TIPO TK_ID
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

			// LÓGICA CORRIGIDA E SIMPLIFICADA
			// Se for uma classe, chama a função recursiva para alocar todos os membros.
			if (eh_classe) {
				$$.traducao += gerar_codigo_alocacao_membros(c_code_name, $1.tipo);
			}

			if ($1.tipo == "string") {
				if (pilha_funcoes_atuais.empty()){
					strings_a_liberar.push_back(c_code_name);
				}
			}
		}
	}
}
| TIPO TK_ID '=' E
    {
        string original_name = $2.label;
        string c_code_name = gentempcode();
        string tipo_declarado = $1.tipo;
        

        $$ = $4; // Começa copiando os atributos da expressão da direita
        $$.label = c_code_name;
        $$.tipo = tipo_declarado;
        $$.nome_original = original_name;

        if (declarar_simbolo(original_name, tipo_declarado, c_code_name)) {
            declaracoes_temp.top()[c_code_name] = tipo_declarado;
            mapa_c_para_original.top()[c_code_name] = original_name;

            if (tipo_declarado == "string") {
                if ($4.tipo != "string") {
                    yyerror("Erro Semantico: tipo incompatível na atribuição da declaração de '" + original_name + "'. Esperado 'string', recebido '" + $4.tipo + "'.");
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
    }
| TIPO TK_ID '[' E ']' '[' E ']'
	{
		if ($4.tipo != "int" || $7.tipo != "int") {
			yyerror("Erro Semantico: As dimensoes de uma matriz devem ser inteiras.");
			$$ = atributos();
		} else {
			string original_name = $2.label;
			if (buscar_simbolo(original_name)) {
				yyerror("Erro Semantico: Variavel '" + original_name + "' ja declarada.");
				$$ = atributos();
			} else {
                if (estamos_definindo_classe) {
                if (!$4.eh_literal || !$7.eh_literal) { yyerror("Erro: As dimensoes de uma matriz membro de classe devem ser constantes.");}
                $$.nome_original = $2.label;
                $$.tipo = "matriz";
                $$.tipo_base = $1.tipo;
                $$.valor_linhas = $4.valor_literal;
                $$.valor_colunas = $7.valor_literal;
                $$.traducao = "";
		    } else {
				string c_type_base;
				if ($1.tipo == "string") {
					c_type_base = "char";
				} else {
					c_type_base = mapa_tipos_linguagem_para_c.at($1.tipo);
				}

				string c_name = gentempcode(); // FIX
				atributos mat_attrs;
				mat_attrs.label = c_name;
				mat_attrs.tipo = "matriz";
				mat_attrs.tipo_base = ($1.tipo == "string") ? "char" : $1.tipo;
				mat_attrs.eh_vetor = true; 
				mat_attrs.label_linhas = $4.label;
				mat_attrs.label_colunas = $7.label;

				if ($4.eh_literal) {
					mat_attrs.valor_linhas = $4.valor_literal;
				} else {
					mat_attrs.valor_linhas = -1; 
				}

				if ($7.eh_literal) {
					mat_attrs.valor_colunas = $7.valor_literal;
				} else {
					mat_attrs.valor_colunas = -1; 
				}

				pilha_tabelas_simbolos.back()[original_name] = mat_attrs;
				
				string temp_loop_var = gentempcode(); // FIX
				string temp_condicao = gentempcode(); // FIX
				string label_inicio_loop = genlabel();
				string label_fim_loop = genlabel();
				string temp_addr_ptr = gentempcode(); // FIX
				string temp_malloc_result = gentempcode(); // FIX

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
| TIPO TK_ID '[' E ']'
    {
        if ($4.tipo != "int") {
            yyerror("Erro Semantico: O tamanho de um vetor deve ser um inteiro.");
            $$ = atributos();
        } else {
            string original_name = $2.label;
            if (buscar_simbolo(original_name)) {
                 yyerror("Erro Semantico: Variavel '" + original_name + "' ja declarada.");
                 $$ = atributos();
            } else {
                if (estamos_definindo_classe) {
                if (!$4.eh_literal) { yyerror("Erro: O tamanho de um vetor membro de classe deve ser uma constante."); }
                $$.nome_original = $2.label;
                $$.tipo = "vetor";
                $$.tipo_base = $1.tipo;
                $$.valor_linhas = $4.valor_literal;
                $$.traducao = "";
            } else {
                string c_name = gentempcode();
                string c_type = mapa_tipos_linguagem_para_c.at($1.tipo);
                int tamanho_do_tipo = mapa_tamanhos_tipos.at($1.tipo);
                // Adiciona na tabela de símbolos
                atributos vet_attrs;
                vet_attrs.label = c_name;
                vet_attrs.tipo = "vetor";
                vet_attrs.tipo_base = $1.tipo;
                vet_attrs.eh_vetor = true;
                vet_attrs.eh_endereco = false;
                pilha_tabelas_simbolos.back()[original_name] = vet_attrs;
                
                // Gera o código de declaração (ponteiro) e alocação (malloc)
                string c_type_base = mapa_tipos_linguagem_para_c.at($1.tipo);
                declaracoes_temp.top()[c_name] = c_type_base + "*";
                mapa_c_para_original.top()[c_name] = original_name;

                $$.traducao = $4.traducao; // Código da expressão do tamanho
                $$.traducao += "\t" + c_name + " = (" + c_type + "*) malloc(" + $4.label + " * " + "sizeof(" + c_type + ")" + ");\n";
                
                // Registra para liberar a memória depois
                strings_a_liberar.push_back(c_name);
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
    | TK_ID          {
						  if (classes_definidas.count($1.label)) {
							  $$.tipo = $1.label;
						  } else {
							  yyerror("Tipo ou classe '" + $1.label + "' nao foi definido.");
							  $$.tipo = "error";
						  }
					  }
	 ;
    ;

E : POSTFIX_E '=' E
{
	atributos lhs = $1;
	atributos rhs = $3;

	// Caso 1: Atribuição de Struct
	if (classes_definidas.count(lhs.tipo) && lhs.tipo == rhs.tipo) {
		rhs = desreferenciar_se_necessario(rhs);
		$$.traducao = lhs.traducao + rhs.traducao;
		if (lhs.eh_endereco) {
			$$.traducao += "\t*" + lhs.label + " = " + rhs.label + ";\n";
		} else {
			$$.traducao += "\t" + lhs.label + " = " + rhs.label + ";\n";
		}
		$$.label = lhs.label;
		$$.tipo = lhs.tipo;
	}
	// Caso 2: Atribuição de Matriz
	else if (lhs.tipo == "matriz" && rhs.tipo == "matriz") {
		rhs = desreferenciar_se_necessario(rhs);
		$$.traducao = lhs.traducao + rhs.traducao;

		matrizes_a_liberar.erase(
			std::remove_if(matrizes_a_liberar.begin(), matrizes_a_liberar.end(),
				[&](const pair<string, string>& p){ return p.first == rhs.label; }),
			matrizes_a_liberar.end()
		);
		for (auto& p : matrizes_a_liberar) {
			if (p.first == lhs.label) {
				p.second = rhs.label_linhas;
				break;
			}
		}
		atributos* lhs_symbol = buscar_simbolo(lhs.nome_original);
		if (lhs_symbol) {
			lhs_symbol->label_linhas = rhs.label_linhas;
			lhs_symbol->label_colunas = rhs.label_colunas;
			lhs_symbol->valor_linhas = rhs.valor_linhas;
			lhs_symbol->valor_colunas = rhs.valor_colunas;
		}

		// LÓGICA CORRIGIDA: Verifica se o LHS é um endereço
		if (lhs.eh_endereco) {
			$$.traducao += "\t*" + lhs.label + " = " + rhs.label + ";\n";
		} else {
			$$.traducao += "\t" + lhs.label + " = " + rhs.label + ";\n";
		}
		
		$$.label = lhs.label;
		$$.tipo = lhs.tipo;
	}
	// Caso 3: Atribuição a membro do tipo string
	else if (lhs.tipo == "string" && lhs.eh_endereco) {
		if (rhs.tipo != "string") {
			yyerror("Erro Semantico: tipo incompativel para atribuir a membro de string.");
			$$ = atributos();
		} else {
			string temp_new_str = gentempcode();
			declaracoes_temp.top()[temp_new_str] = "char*";
			string codigo_copia = contar_string(temp_new_str, rhs);
			$$.traducao = rhs.traducao + codigo_copia + lhs.traducao;
			$$.traducao += "\t*" + lhs.label + " = " + temp_new_str + ";\n";
			strings_a_liberar.push_back(temp_new_str);
			$$.label = lhs.label; 
			$$.tipo = lhs.tipo;
		}
	}
	// Caso 4: Atribuição a variável do tipo string
	else if (lhs.tipo == "string" && !lhs.eh_endereco) {
		rhs = desreferenciar_se_necessario(rhs);
		if (rhs.tipo != "string") {
			yyerror("Erro Semantico: tipos incompativeis para atribuir a string '" + lhs.nome_original + "'.");
			$$.tipo = "error";
		} else {
			$$.traducao = rhs.traducao;
			string temp_cond = gentempcode();
			declaracoes_temp.top()[temp_cond] = "int";
			string label_skip_free = genlabel();
			$$.traducao += "\t" + temp_cond + " = " + lhs.label + " == NULL;\n";
			$$.traducao += "\tif (" + temp_cond + ") goto " + label_skip_free + ";\n";
			$$.traducao += "\tfree(" + lhs.label + ");\n";
			$$.traducao += label_skip_free + ":\n";
			string codigo_copia = contar_string(lhs.label, rhs);
			$$.traducao += codigo_copia;
			$$.label = lhs.label;
			$$.tipo = lhs.tipo;
			atualizar_info_string_simbolo(lhs.nome_original, rhs);
		}
	}
	// Caso 5: Demais atribuições (primitivos)
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
		$$.label = lhs.label;
		$$.tipo = lhs.tipo;
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
  | UNARY_E
    {
        $$ = $1;
    }
    ;

UNARY_E : TK_MAIS_MAIS UNARY_E  { $$ = criar_expressao_unaria($2, "+"); }
        | TK_MENOS_MENOS UNARY_E { $$ = criar_expressao_unaria($2, "-"); }
        | '~' UNARY_E            { $$ = criar_expressao_unaria($2, "~"); }
        | '-' E %prec UMINUS
        {
            atributos operando = desreferenciar_se_necessario($2);

            if (operando.tipo != "int" && operando.tipo != "float") {
                yyerror("Erro Semantico: O operador de negacao '-' so pode ser aplicado a tipos numericos (int, float).");
                $$ = atributos(); 
            } else {
                
                $$ = operando; 
                $$.label = gentempcode();
                declaracoes_temp.top()[$$.label] = $$.tipo;

                
                $$.traducao = operando.traducao;

               
                if (operando.tipo == "float") {
                    $$.traducao += "\t" + $$.label + " = -1.0 * " + operando.label + ";\n";
                } else { 
                    $$.traducao += "\t" + $$.label + " = -1 * " + operando.label + ";\n";
                }

                
                if (operando.eh_literal) {
                    $$.valor_literal = -operando.valor_literal;
                }
            }
        }
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

				// Agora aceita tanto uma definição completa ('function') quanto um protótipo ('function_prototype')
				if (!simb || (simb->kind != "function" && simb->kind != "function_prototype")) {
					yyerror("'" + nome_funcao + "' nao e uma funcao ou nao foi declarada.");
					$$.tipo = "error";
				} else {
					vector<atributos> args = $3.args;
					if (args.size() != simb->params.size()) {
						yyerror("Numero incorreto de argumentos para a funcao '" + nome_funcao + "'. Esperado: " + to_string(simb->params.size()) + ", Recebido: " + to_string(args.size()));
						$$.tipo = "error";
					} else {
						string codigo_args;
						string c_args_list;

						for (size_t i = 0; i < args.size(); ++i) {
							atributos arg = desreferenciar_se_necessario(args[i]);
							string param_tipo = simb->params[i].tipo;
							if(arg.tipo != param_tipo && !(param_tipo == "float" && arg.tipo == "int")) {
								yyerror("Tipo do argumento " + to_string(i+1) + " incompativel na chamada de '" + nome_funcao + "'.");
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
						$$.tipo = simb->tipo;

						if ($$.tipo != "void") {
							$$.label = gentempcode();
							declaracoes_temp.top()[$$.label] = $$.tipo;
							$$.traducao += "\t" + $$.label + " = " + nome_funcao + "(" + c_args_list + ");\n";
							if ($$.tipo == "string") {
								strings_a_liberar.push_back($$.label);
							}
						} else {
							$$.label = "";
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

	if ((base.tipo != "vetor" && base.tipo != "matriz")) {
		yyerror("Erro Semantico: Variavel '" + base.nome_original + "' nao e um vetor ou matriz.");
		$$ = atributos();
	} else if (indice.tipo != "int") {
		yyerror("Erro Semantico: Indice de vetor ou matriz deve ser um inteiro.");
		$$ = atributos();
	} else {
		string base_ptr_label = base.label;
		$$.traducao = base.traducao + indice.traducao;

		// Bloco para desreferenciar o ponteiro base se ele for um endereço (ex: vindo de um acesso a membro de struct)
		if (base.eh_endereco) {
			string dereferenced_ptr = gentempcode();
			string dereferenced_ptr_type;

			// Determina o tipo do ponteiro após a desreferência
			// Se a base é uma 'matriz' (ex: p.dados), desreferenciar dá o ponteiro da matriz (float**)
			// Se a base é um 'vetor' (ex: p.dados[i]), desreferenciar dá o ponteiro da linha (float*)
			if (base.tipo == "matriz") {
				 dereferenced_ptr_type = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "**";
			} else { // base.tipo == "vetor"
				 dereferenced_ptr_type = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "*";
			}
			
			declaracoes_temp.top()[dereferenced_ptr] = dereferenced_ptr_type;
			$$.traducao += "\t" + dereferenced_ptr + " = *" + base.label + ";\n";
			base_ptr_label = dereferenced_ptr; // O novo ponteiro base para a aritmética é o que foi desreferenciado
		}

		// Bloco para fazer a aritmética de ponteiro (base + índice)
		string element_addr_ptr = gentempcode();
		string element_addr_ptr_type;
		
		// Determina o tipo do ponteiro resultante da soma
		if (base.tipo == "matriz") {
			element_addr_ptr_type = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "**";
		} else { // base.tipo == "vetor"
			element_addr_ptr_type = mapa_tipos_linguagem_para_c.at(base.tipo_base) + "*";
		}
		
		declaracoes_temp.top()[element_addr_ptr] = element_addr_ptr_type;
		$$.traducao += "\t" + element_addr_ptr + " = " + base_ptr_label + " + " + indice.label + ";\n";

		// Define os atributos do resultado desta expressão de acesso
		$$.label = element_addr_ptr;
		$$.eh_endereco = true;
		$$.nome_original = base.nome_original;

		// Atualiza o tipo semântico para o próximo acesso
		if (base.tipo == "matriz") {
			$$.tipo = "vetor";
			$$.tipo_base = base.tipo_base;
		} else { // base.tipo == "vetor"
			$$.tipo = base.tipo_base;
			$$.tipo_base = "";
		}
	}
}

| POSTFIX_E TK_PONTO TK_ID
{
	atributos base_obj = $1;
	string nome_membro = $3.label;

	// O tipo da base é o que está no atributo 'tipo' (ex: "PacoteDeMatrizes")
	string tipo_base_real = base_obj.tipo;
	
	auto it_classe = classes_definidas.find(tipo_base_real);
	if (it_classe == classes_definidas.end()) {
		yyerror("Erro: Acesso de membro '.' em tipo nao-classe: '" + base_obj.nome_original + "'.");
		$$ = atributos();
	} else {
		auto& classe_info = it_classe->second;
		MemberInfo* membro_info = nullptr;
		for(auto& m : classe_info.membros) { if (m.nome == nome_membro) { membro_info = &m; break; } }

		if (membro_info == nullptr) {
			yyerror("Erro: Classe '" + tipo_base_real + "' nao tem membro '" + nome_membro + "'.");
			$$ = atributos();
		} else {
			$$.traducao = base_obj.traducao;
			$$.nome_original = base_obj.nome_original + "." + nome_membro;
			$$.tipo = membro_info->tipo;
			$$.tipo_base = membro_info->tipo_base;
			
			// --- INÍCIO DA CORREÇÃO ---
			// Copia as dimensões conhecidas em tempo de compilação
			$$.valor_linhas = membro_info->valor_linhas;
			$$.valor_colunas = membro_info->valor_colunas;

			// Se o membro é um vetor ou matriz, gera temporários para as dimensões
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
			// --- FIM DA CORREÇÃO ---

			string addr_temp = gentempcode();
			string member_c_type;
			
			if (membro_info->tipo == "vetor")      member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo_base) + "*";
			else if (membro_info->tipo == "matriz") member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo_base) + "**";
			else if (classes_definidas.count(membro_info->tipo)) member_c_type = "struct " + membro_info->tipo;
			else member_c_type = mapa_tipos_linguagem_para_c.at(membro_info->tipo);

			string temp_addr_type = member_c_type + "*";
			declaracoes_temp.top()[addr_temp] = temp_addr_type;
			
			if (base_obj.eh_endereco) {
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