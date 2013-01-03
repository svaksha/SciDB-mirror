%{
#include <stdio.h>
#include <string>
#include <vector>
#include <iostream>
#include <stdint.h>
#include <limits>

#include <boost/format.hpp>

#include "iquery/commands.h"
%}

%require "2.3"
%debug
%start start
%defines
%skeleton "lalr1.cc"
%name-prefix="yy"
%define "parser_class_name" "Parser"
%locations
%verbose

%parse-param { class IqueryParser& glue }

%error-verbose

%union {
	int64_t int64Val;
	double realVal;	
    std::string* stringVal;
	class IqueryCmd* node;
	bool boolean;
	const char* constString;
}

%type <node> start commands set setlang setfetch settimer setverbose help quit knownerror afl_help
             setformat

%type <constString> format

%type <int64Val> langtype

%destructor { delete $$; } IDENTIFIER STRING_LITERAL

%token SET LANG AFL AQL NO FETCH VERBOSE TIMER HELP QUIT FORMAT
       AUTO OPAQUE CSV CSV_PLUS LCSV_PLUS DENSE LSPARSE SPARSE TEXT DCSV

%token	EOQ     	0 "end of query"
%token	EOL			"end of line"
%token <stringVal> 	IDENTIFIER	"identifier"
%token <int64Val>	INTEGER "integer"
%token <realVal>	REAL "real"
%token <stringVal>	STRING_LITERAL "string"

%{
#include "iquery/iquery_parser.h"
#include "iquery/scanner.h"
#undef yylex
#define yylex glue._scanner->lex
%}

%%

start:
    commands
    {
        //This is well-parsed iquery command, mark it
        glue._iqueryCommand = true;
        glue._cmd = $1;
    }
    ;

commands:
    set
    | setlang
    | setfetch
    | settimer
    | setverbose
    | setformat
    | help
    | quit
    | afl_help
    | knownerror
    ;
    
knownerror:
    SET error
    {
        // This is syntax error, but it clearly iquery command, so we mark it and later not sending
        // to server as AQL/AFL query showing iquery's error message instead.
        glue._iqueryCommand = true;
        $$ = NULL;
        YYABORT;
    }
    ;

set:
    SET
    {
        $$ = new IqueryCmd(IqueryCmd::SET);
    }
    ;

setlang:
    SET LANG langtype
    {
        $$ = new IntIqueryCmd(IqueryCmd::LANG, $3);
    }
    ;

langtype:
    AQL
    {
        $$ = 0;
    }
    | AFL
    {
        $$ = 1;
    }
    ;

setfetch:
    SET FETCH
    {
        $$ = new IntIqueryCmd(IqueryCmd::FETCH, 1);
    }
    | SET NO FETCH
    {
        $$ = new IntIqueryCmd(IqueryCmd::FETCH, 0);
    }
    ;

settimer:
    SET TIMER
    {
        $$ = new IntIqueryCmd(IqueryCmd::TIMER, 1);
    }
    | SET NO TIMER
    {
        $$ = new IntIqueryCmd(IqueryCmd::TIMER, 0);
    }
    ;

setverbose:
    SET VERBOSE
    {
        $$ = new IntIqueryCmd(IqueryCmd::VERBOSE, 1);
    }
    | SET NO VERBOSE
    {
        $$ = new IntIqueryCmd(IqueryCmd::VERBOSE, 0);
    }
    ;

setformat:
    SET FORMAT STRING_LITERAL
    {
        $$ = new StrIqueryCmd(IqueryCmd::BINARY_FORMAT, *$3);
        delete $3;
    }
    | SET FORMAT format
    {
        $$ = new StrIqueryCmd(IqueryCmd::FORMAT, $3);
    }
    ;

format:
    AUTO
    {
        $$ = "auto";
    }
    | OPAQUE
    {
        $$ = "opaque";
    }
    | CSV
    {
        $$ = "csv";
    }
    | CSV_PLUS
    {
        $$ = "csv+";
    }
    | LCSV_PLUS
    {
        $$ = "lcsv+";
    }
    | DENSE
    {
        $$ = "dense";
    }
    | LSPARSE
    {
        $$ = "lsparse";
    }
    | SPARSE
    {
        $$ = "sparse";
    }
    | TEXT
    {
        $$ = "text";
    }
    | DCSV
    {
        $$ = "dcsv";
    }
    ;

help:
    HELP
    {
        $$ = new IqueryCmd(IqueryCmd::HELP);
    }
    ;

quit:
    QUIT
    {
        $$ = new IqueryCmd(IqueryCmd::QUIT);
    }
    ;

afl_help:
    HELP '(' error
    {
        //Stop parsing when such combination found in begin to avoid overlap with AFL operator HELP
        glue._iqueryCommand = false;
        $$ = NULL;
        YYABORT;
    }
    ;

%%

void yy::Parser::error(const yy::Parser::location_type& loc,
	const std::string& msg)
{
	glue.error(loc, msg);
}
