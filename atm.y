%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* Flex buffer functions for scanning strings */
typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern YY_BUFFER_STATE yy_scan_string(const char *);
extern void yy_delete_buffer(YY_BUFFER_STATE);

/* Declare flex function to reset input buffer */
extern void yyrestart(FILE *);

#define MAX_ACCOUNTS 100
#define MAX_HISTORY 10
#define DAILY_LIMIT_DEFAULT 10000

typedef enum {
    STATE_LOGGED_OUT,
    STATE_PENDING_2FA,
    STATE_USER_LOGGED_IN,
    STATE_ADMIN_LOGGED_IN,
    STATE_PENDING_AUTHORIZATION
} SessionState;

typedef struct {
    int ac_no;
    int pin;
    int balance;
    char name[50];
    char city[50];
    char security_answer[50];
    char history[MAX_HISTORY][100];
    int hist_count;
    int daily_out;
} Account;

Account accounts[MAX_ACCOUNTS];
int account_count = 0;
int next_ac_no = 1001;

SessionState state = STATE_LOGGED_OUT;
int current_ac_index = -1;   // index of logged-in user
int otp_code = 0;
char current_city[50] = "";

// pending transaction for location-based authorization
typedef enum { PT_WITHDRAW, PT_TRANSFER, PT_BILL } PendingType;
PendingType pending_type;
int pending_amount = 0;
char pending_target[50] = "";
char pending_bill_type[50] = "";

int daily_limit = DAILY_LIMIT_DEFAULT;

void yyerror(const char *s) { fprintf(stderr, "Error: %s\n", s); }
int yylex();
void add_history(Account *acc, const char *msg);
Account* find_account_by_name(const char *name);
int check_daily_limit(Account *acc, int amount);
void reset_daily_limits();
void execute_pending();
%}

%union {
    int num;
    char *str;
}

%token CREATE ACCOUNT LOGIN VERIFY LOGOUT BALANCE DEPOSIT WITHDRAW
%token TRANSFER TO PAY BILL STATEMENT ADMIN VIEW ALL
%token SET CITY NEW DAY HELP EXIT AUTHORIZE CHANGE PIN
%token <num> NUMBER
%token <str> NAME
%token NEWLINE

%type <str> name

%%

program:
    program statement NEWLINE
    | program NEWLINE
    | /* empty */
    ;

statement:
    create_account   { ; }
    | login          { ; }
    | verify         { ; }
    | logout         { ; }
    | balance        { ; }
    | deposit        { ; }
    | withdraw       { ; }
    | transfer       { ; }
    | pay_bill       { ; }
    | statement_cmd  { ; }
    | admin_login    { ; }
    | view_all       { ; }
    | set_city       { ; }
    | new_day        { ; }
    | help           { ; }
    | exit_cmd       { ; }
    | authorize_cmd  { ; }
    | change_pin     { ; }
    ;

create_account:
    CREATE ACCOUNT name NUMBER name name
    {
        if (account_count >= MAX_ACCOUNTS) {
            printf("Error: Max accounts reached.\n");
        } else {
            Account *a = &accounts[account_count];
            a->ac_no = next_ac_no++;
            strcpy(a->name, $3);
            a->pin = $4;
            strcpy(a->city, $5);
            strcpy(a->security_answer, $6);
            a->balance = 0;
            a->hist_count = 0;
            a->daily_out = 0;
            account_count++;
            printf("Success! Account created. Your AcNo is %d.\n", a->ac_no);
            free($3); free($5); free($6);
        }
    }
    ;

login:
    LOGIN name NUMBER
    {
        if (strcasecmp($2, "ADMIN") == 0) {
            // ADMIN login handled separately
            free($2);
            YYABORT; // not allowed here, use admin_login
        } else {
            // regular login with name (acno is a number but we used name for flexibility)
            free($2);
            printf("Error: Please use LOGIN <AcNo> <PIN>\n");
        }
    }
    | LOGIN NUMBER NUMBER
    {
        if (state != STATE_LOGGED_OUT) {
            printf("Error: Already logged in.\n");
        } else {
            int found = 0;
            for (int i=0; i<account_count; i++) {
                if (accounts[i].ac_no == $2 && accounts[i].pin == $3) {
                    current_ac_index = i;
                    otp_code = rand() % 9000 + 1000;  // 4-digit OTP
                    state = STATE_PENDING_2FA;
                    printf("Credentials accepted. 2FA required. OTP sent: %04d. Please enter VERIFY <OTP>\n", otp_code);
                    found = 1;
                    break;
                }
            }
            if (!found)
                printf("Invalid AcNo or PIN.\n");
        }
    }
    ;

verify:
    VERIFY NUMBER
    {
        if (state != STATE_PENDING_2FA) {
            printf("Error: No 2FA pending.\n");
        } else if ($2 == otp_code) {
            state = STATE_USER_LOGGED_IN;
            strcpy(current_city, accounts[current_ac_index].city);
            printf("2FA Successful. Welcome %s!\n", accounts[current_ac_index].name);
        } else {
            state = STATE_LOGGED_OUT;
            current_ac_index = -1;
            printf("Wrong OTP. Login cancelled.\n");
        }
    }
    ;

logout:
    LOGOUT
    {
        if (state == STATE_USER_LOGGED_IN || state == STATE_ADMIN_LOGGED_IN) {
            state = STATE_LOGGED_OUT;
            current_ac_index = -1;
            strcpy(current_city, "");
            printf("Logged out successfully.\n");
        } else {
            printf("Error: Not logged in.\n");
        }
    }
    ;

balance:
    BALANCE
    {
        if (state == STATE_USER_LOGGED_IN) {
            Account *a = &accounts[current_ac_index];
            printf("Balance: %d\n", a->balance);
        } else printf("Error: Login required.\n");
    }
    ;

deposit:
    DEPOSIT NUMBER
    {
        if (state == STATE_USER_LOGGED_IN) {
            Account *a = &accounts[current_ac_index];
            a->balance += $2;
            char buf[80];
            sprintf(buf, "Deposited %d", $2);
            add_history(a, buf);
            printf("%d Deposited. Current Balance: %d\n", $2, a->balance);
        } else printf("Error: Login required.\n");
    }
    ;

withdraw:
    WITHDRAW NUMBER
    {
        if (state != STATE_USER_LOGGED_IN) {
            printf("Error: Login required.\n");
        } else {
            Account *a = &accounts[current_ac_index];
            // city check
            if (strcmp(current_city, a->city) != 0) {
                printf("Transaction blocked: different city (%s vs %s). Authorize with AUTHORIZE <answer>\n", current_city, a->city);
                pending_type = PT_WITHDRAW;
                pending_amount = $2;
                state = STATE_PENDING_AUTHORIZATION;
            } else if (a->balance < $2) {
                printf("Insufficient funds.\n");
            } else if (!check_daily_limit(a, $2)) {
                printf("Daily limit exceeded.\n");
            } else {
                a->balance -= $2;
                a->daily_out += $2;
                char buf[80];
                sprintf(buf, "Withdrew %d", $2);
                add_history(a, buf);
                printf("Withdrawn %d. Current Balance: %d\n", $2, a->balance);
            }
        }
    }
    ;

transfer:
    TRANSFER NUMBER TO name
    {
        if (state != STATE_USER_LOGGED_IN) {
            printf("Error: Login required.\n");
            free($4);
        } else {
            Account *src = &accounts[current_ac_index];
            Account *tgt = find_account_by_name($4);
            if (!tgt) {
                printf("Target account not found.\n");
                free($4);
            } else if (strcmp(current_city, src->city) != 0) {
                printf("Transaction blocked: different city. Authorize with AUTHORIZE <answer>\n");
                pending_type = PT_TRANSFER;
                pending_amount = $2;
                strcpy(pending_target, $4);
                state = STATE_PENDING_AUTHORIZATION;
                free($4);
            } else if (src->balance < $2) {
                printf("Insufficient funds.\n");
                free($4);
            } else if (!check_daily_limit(src, $2)) {
                printf("Daily limit exceeded.\n");
                free($4);
            } else {
                src->balance -= $2;
                src->daily_out += $2;
                tgt->balance += $2;
                char buf[100];
                sprintf(buf, "Transferred %d to %s", $2, $4);
                add_history(src, buf);
                sprintf(buf, "Received %d from %s", $2, src->name);
                add_history(tgt, buf);
                printf("Successfully transferred %d to %s. Current Balance: %d\n", $2, $4, src->balance);
                free($4);
            }
        }
    }
    ;

pay_bill:
    PAY BILL name NUMBER
    {
        if (state != STATE_USER_LOGGED_IN) {
            printf("Error: Login required.\n");
            free($3);
        } else {
            Account *a = &accounts[current_ac_index];
            if (strcmp(current_city, a->city) != 0) {
                printf("Transaction blocked: different city. Authorize with AUTHORIZE <answer>\n");
                pending_type = PT_BILL;
                pending_amount = $4;
                strcpy(pending_bill_type, $3);
                state = STATE_PENDING_AUTHORIZATION;
                free($3);
            } else if (a->balance < $4) {
                printf("Insufficient funds.\n");
                free($3);
            } else if (!check_daily_limit(a, $4)) {
                printf("Daily limit exceeded.\n");
                free($3);
            } else {
                a->balance -= $4;
                a->daily_out += $4;
                char buf[100];
                sprintf(buf, "Paid bill %s %d", $3, $4);
                add_history(a, buf);
                printf("Bill Paid. %d deducted. Current Balance: %d\n", $4, a->balance);
                free($3);
            }
        }
    }
    ;

statement_cmd:
    STATEMENT
    {
        if (state == STATE_USER_LOGGED_IN) {
            Account *a = &accounts[current_ac_index];
            if (a->hist_count == 0) printf("No transactions yet.\n");
            else for (int i=0; i<a->hist_count; i++)
                printf("%d. %s\n", i+1, a->history[i]);
        } else printf("Error: Login required.\n");
    }
    ;

admin_login:
    ADMIN LOGIN NUMBER
    {
        if (state != STATE_LOGGED_OUT) printf("Error: Already logged in.\n");
        else if ($3 == 9999) {
            state = STATE_ADMIN_LOGGED_IN;
            printf("Welcome Administrator.\n");
        } else printf("Invalid admin PIN.\n");
    }
    ;

view_all:
    VIEW ALL
    {
        if (state == STATE_ADMIN_LOGGED_IN) {
            for (int i=0; i<account_count; i++)
                printf("[%d] %s - Balance: %d (City: %s)\n", accounts[i].ac_no, accounts[i].name, accounts[i].balance, accounts[i].city);
        } else printf("Error: Admin access required.\n");
    }
    ;

set_city:
    SET CITY name
    {
        strcpy(current_city, $3);
        printf("Current city set to %s\n", current_city);
        free($3);
    }
    ;

new_day:
    NEW DAY
    {
        reset_daily_limits();
        printf("New day started. Daily limits reset.\n");
    }
    ;

help:
    HELP
    {
        printf("Commands:\n");
        fflush(stdout);
        printf("CREATE ACCOUNT <name> <PIN> <city> <security_answer>\n");
        fflush(stdout);
        printf("LOGIN <AcNo> <PIN>\n");
        fflush(stdout);
        printf("VERIFY <OTP>\n");
        fflush(stdout);
        printf("LOGOUT\n");
        fflush(stdout);
        printf("BALANCE\n");
        fflush(stdout);
        printf("DEPOSIT <amt>\n");
        fflush(stdout);
        printf("WITHDRAW <amt>\n");
        fflush(stdout);
        printf("TRANSFER <amt> TO <name>\n");
        fflush(stdout);
        printf("PAY BILL <type> <amt>\n");
        fflush(stdout);
        printf("STATEMENT\n");
        fflush(stdout);
        printf("CHANGE PIN <old> <new>\n");
        fflush(stdout);
        printf("SET CITY <city>\n");
        fflush(stdout);
        printf("AUTHORIZE <answer>\n");
        fflush(stdout);
        printf("ADMIN LOGIN <9999>\n");
        fflush(stdout);
        printf("VIEW ALL (admin)\n");
        fflush(stdout);
        printf("NEW DAY\n");
        fflush(stdout);
        printf("HELP\n");
        fflush(stdout);
        printf("EXIT\n");
        fflush(stdout);
    }
    ;

exit_cmd:
    EXIT { printf("Goodbye.\n"); exit(0); }
    ;

authorize_cmd:
    AUTHORIZE name
    {
        if (state != STATE_PENDING_AUTHORIZATION) {
            printf("No pending authorization.\n");
            free($2);
        } else {
            Account *a = &accounts[current_ac_index];
            if (strcmp($2, a->security_answer) == 0) {
                state = STATE_USER_LOGGED_IN;
                execute_pending();
            } else {
                state = STATE_USER_LOGGED_IN;
                printf("Authorization failed. Transaction cancelled.\n");
            }
            free($2);
        }
    }
    ;

change_pin:
    CHANGE PIN NUMBER NUMBER
    {
        if (state == STATE_USER_LOGGED_IN) {
            Account *a = &accounts[current_ac_index];
            if ($3 != a->pin) {
                printf("Incorrect current PIN.\n");
            } else {
                a->pin = $4;
                printf("PIN changed successfully.\n");
            }
        } else printf("Error: Login required.\n");
    }
    ;

name: NAME { $$ = $1; }
%%

void add_history(Account *acc, const char *msg) {
    if (acc->hist_count >= MAX_HISTORY) {
        for (int i=0; i<MAX_HISTORY-1; i++)
            strcpy(acc->history[i], acc->history[i+1]);
        acc->hist_count = MAX_HISTORY-1;
    }
    strcpy(acc->history[acc->hist_count++], msg);
}

Account* find_account_by_name(const char *name) {
    for (int i=0; i<account_count; i++)
        if (strcmp(accounts[i].name, name) == 0)
            return &accounts[i];
    return NULL;
}

int check_daily_limit(Account *acc, int amount) {
    if (acc->daily_out + amount > daily_limit) return 0;
    return 1;
}

void reset_daily_limits() {
    for (int i=0; i<account_count; i++)
        accounts[i].daily_out = 0;
}

void execute_pending() {
    Account *a = &accounts[current_ac_index];
    switch (pending_type) {
        case PT_WITHDRAW: {
            if (a->balance < pending_amount)
                printf("Authorized but insufficient funds.\n");
            else if (!check_daily_limit(a, pending_amount))
                printf("Authorized but daily limit exceeded.\n");
            else {
                a->balance -= pending_amount;
                a->daily_out += pending_amount;
                char buf[80];
                sprintf(buf, "Withdrew %d (auth)", pending_amount);
                add_history(a, buf);
                printf("Authorized: Withdrawn %d. Balance: %d\n", pending_amount, a->balance);
            }
            break;
        }
        case PT_TRANSFER: {
            Account *tgt = find_account_by_name(pending_target);
            if (!tgt) printf("Authorized but target account gone.\n");
            else if (a->balance < pending_amount)
                printf("Authorized but insufficient funds.\n");
            else if (!check_daily_limit(a, pending_amount))
                printf("Authorized but daily limit exceeded.\n");
            else {
                a->balance -= pending_amount;
                a->daily_out += pending_amount;
                tgt->balance += pending_amount;
                char buf[100];
                sprintf(buf, "Transferred %d to %s (auth)", pending_amount, pending_target);
                add_history(a, buf);
                sprintf(buf, "Received %d from %s", pending_amount, a->name);
                add_history(tgt, buf);
                printf("Authorized: Transferred %d to %s. Balance: %d\n", pending_amount, pending_target, a->balance);
            }
            break;
        }
        case PT_BILL: {
            if (a->balance < pending_amount)
                printf("Authorized but insufficient funds.\n");
            else if (!check_daily_limit(a, pending_amount))
                printf("Authorized but daily limit exceeded.\n");
            else {
                a->balance -= pending_amount;
                a->daily_out += pending_amount;
                char buf[100];
                sprintf(buf, "Paid bill %s %d (auth)", pending_bill_type, pending_amount);
                add_history(a, buf);
                printf("Authorized: Paid %s bill %d. Balance: %d\n", pending_bill_type, pending_amount, a->balance);
            }
            break;
        }
    }
}

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    srand(time(NULL));

    char line[256];
    while (fgets(line, sizeof(line), stdin)) {
        // line includes the trailing newline; the grammar expects it
        YY_BUFFER_STATE buf = yy_scan_string(line);
        yyparse();
        yy_delete_buffer(buf);
        // global session state persists between commands
    }
    return 0;
}