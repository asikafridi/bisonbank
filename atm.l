%{
#include "atm.tab.h"
#include <string.h>
#include <stdlib.h>
%}

%option noyywrap
%option yylineno

%%

"CREATE"        { return CREATE; }
"ACCOUNT"       { return ACCOUNT; }
"LOGIN"         { return LOGIN; }
"VERIFY"        { return VERIFY; }
"LOGOUT"        { return LOGOUT; }
"BALANCE"       { return BALANCE; }
"DEPOSIT"       { return DEPOSIT; }
"WITHDRAW"      { return WITHDRAW; }
"TRANSFER"      { return TRANSFER; }
"TO"            { return TO; }
"PAY"           { return PAY; }
"BILL"          { return BILL; }
"STATEMENT"     { return STATEMENT; }
"ADMIN"         { return ADMIN; }
"VIEW"          { return VIEW; }
"ALL"           { return ALL; }
"SET"           { return SET; }
"CITY"          { return CITY; }
"NEW"           { return NEW; }
"DAY"           { return DAY; }
"HELP"          { return HELP; }
"EXIT"          { return EXIT; }
"AUTHORIZE"     { return AUTHORIZE; }
"CHANGE"        { return CHANGE; }
"PIN"           { return PIN; }

[0-9]+          { yylval.num = atoi(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]*  { yylval.str = strdup(yytext); return NAME; }

\n              { return NEWLINE; }
[ \t]+          /* ignore whitespace */

.               { /* ignore */ }
%%