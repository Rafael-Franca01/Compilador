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
ID          {LETRA}({LETRA}|{DIGITO})*

%%

(\r\n|\n|\r)          { contador_linha++; }  

{DELIM}		{}

"main"		{ return TK_MAIN; }

"it"		{ return TK_TIPO_INT; }
"ft"		{ return TK_TIPO_FLOAT; }
"cha"      { return TK_TIPO_CHAR; }
"boo"	{ return TK_TIPO_BOOL; }

"true"		{ yylval.label = "1"; yylval.tipo = "boolean"; return TK_TRUE; }
"false"		{ yylval.label = "0"; yylval.tipo = "boolean"; return TK_FALSE; }

"="			{ return '='; }

[(){}[\];,]	{ return *yytext; }

[+\-*/]		{ return *yytext; }

{FLOAT}		{ yylval.label = yytext; yylval.tipo = "float"; return TK_FLOAT; }
{NUM}		{ yylval.label = yytext; yylval.tipo = "int"; return TK_NUM; }
{ID}		{ yylval.label = yytext; return TK_ID; }


.			{ return TK_ERROR; }

%%
