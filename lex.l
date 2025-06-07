%{
#include <string>
#include "y.tab.h"

using namespace std;

%}

ESPACO [ \t]
DIGITO [0-9]
LETRA [A-Za-z_]

DELIM       {ESPACO}+
NUM         {DIGITO}+
FLOAT       {DIGITO}+"."{DIGITO}+
CHAR        \'([^\\]|\\[nrt0\\'"\\])\'
stringo     \"([^\\"]|\\.)*\"
STRING      {stringo}+
ID          {LETRA}({LETRA}|{DIGITO})*

%%

(\r\n|\n|\r)          { contador_linha++; }  

{DELIM}		{}
"main"		{ return TK_MAIN; }
"if"		{ return TK_IF; }
"helcio"	{ return TK_ELSE; }
"swc"		{ return TK_SWITCH; }
"cs"        { return TK_CASE; }
"def"		{ return TK_DEFAULT; }
"whl"		{ return TK_WHILE; }
"do"		{ return TK_DO; }
"for"		{ return TK_FOR; }
"prt"       { return TK_PRINT; }
"brk"       { return TK_BREAK; }
"cnt"       { return TK_CONTINUE; }
"receba"    { return TK_SCANF; }

"int"		{ return TK_TIPO_INT; }
"flt"		{ return TK_TIPO_FLOAT; }
"boo"	    { return TK_TIPO_BOOL; }
"chr"		{ return TK_TIPO_CHAR; }
"str"       { return TK_TIPO_STRING; }

"++"      { return TK_MAIS_MAIS; }
"--"      { return TK_MENOS_MENOS; }

"true"		{ yylval.label = "1"; yylval.tipo = "boolean"; return TK_TRUE; }
"false"		{ yylval.label = "0"; yylval.tipo = "boolean"; return TK_FALSE; }


"="			{ return '='; }

[(){}[\];:,]	{ return *yytext; }

[<]         { return *yytext; }
[>]         { return *yytext; }           
[&]         { return *yytext; }
[|]         { return *yytext; }
[~]         { return *yytext; }
[?]         { return *yytext; }
[+\-*/]		{ return *yytext; }
"<="        { return TK_MENOR_IGUAL; }
">="        { return TK_MAIOR_IGUAL; }
"=="        { return TK_IGUAL_IGUAL; }
"!="        { return TK_DIFERENTE; } 

{STRING} {
    string raw_string(yytext);
    // Processa a string para calcular o tamanho real
    int tamanho_real = 0;
    for (size_t i = 1; i < raw_string.length() - 1; ++i) {
        if (raw_string[i] == '\\') {
            // Se encontrar uma barra invertida, pula o próximo caractere
            // (ex: '\n' conta como 1 char, não 2).
            i++; 
        }
        tamanho_real++;
    }
    
    // Agora, preenchemos o yylval com a informação completa
    yylval.label = raw_string; // O label é a string literal com aspas
    yylval.tipo = "string";
    yylval.tamanho_string = tamanho_real; // O tamanho exato, calculado aqui!
    yylval.literal = true;
    return TK_STRING;
}
{CHAR}      { yylval.label = yytext; yylval.tipo = "char"; return TK_CHAR; }
{FLOAT}		{ yylval.label = yytext; yylval.tipo = "float"; return TK_FLOAT; }
{NUM}		{ yylval.label = yytext; yylval.tipo = "int"; return TK_NUM; }
{ID}		{ yylval.label = yytext; return TK_ID; }


.			{ return TK_ERROR; }

%%
