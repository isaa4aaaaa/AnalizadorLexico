%{
/*
 * Analizador lexico de las nueve clases definidas en el enunciado.
 * Autores: Isaac Campos, Benyy Arriaga.
 * Fecha de realizacion: 27 Septiembre 2026
 */

#include "tablas.h"
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LONGITUD_IDENTIFICADOR 32
#define CANTIDAD(arreglo) ((int)(sizeof(arreglo) / sizeof((arreglo)[0])))

/* Los indices de estos arreglos son los valores indicados en los catalogos. */
static const char *const reservadas[] = {
    "bool", "cad", "cte", "def", "decisión", "elegir", "flot", "fls", "haz",
    "if", "int", "leer", "mientras", "mostrar", "para", "regresa", "vdd"
};
static const char *const asignacion[] = {":=", ":+", ":-", ":*", ":/", ":%"};
static const char *const relacionales[] = {"+q", "-q", "+iq", "-iq", ":i", "d/i"};
static const char *const aritmeticos[] = {"&+", "&-", "&*", "&/", "&&*", "&%&", "&*&"};
static const char *const especiales[] = {"@>", "$$", "#?", "::=", "?=", "%~", "+"};

static unsigned long cantidadErrores = 0;
static int lineaComentario = 1;

static void registrarCatalogo(int clase, const char *const catalogo[], int cantidad);
static void registrarEntero(void);
static void informarError(int linea, const char *mensaje);
static void liberarRecursos(void);
%}

 /* Se evita la dependencia de unistd.h y de las funciones POSIX para terminales. */
%option noyywrap yylineno noinput nounput never-interactive nounistd nodefault
%x COMENTARIO

 /* Se reconocen identificadores completos antes de revisar su longitud.
  * El cuerpo no puede estar vacio y puede contener guiones bajos. */
digito [0-9]
identificador "I_"[A-Za-z0-9_]+"_I"
entero 0i|[pn][1-9]{digito}*i
decimal {digito}*[.]{digito}+
exponente [eE]-?{digito}+
real -?({decimal}({exponente})?|{digito}+{exponente})

 /* ASCII 32..126, excepto >, que termina la cadena. Se admite < interno. */
cadena "<"[\x20-\x3D\x3F-\x7E]*">"
reservada "bool"|"cad"|"cte"|"def"|"decisión"|"elegir"|"flot"|"fls"|"haz"|"if"|"int"|"leer"|"mientras"|"mostrar"|"para"|"regresa"|"vdd"
op_asignacion ":"[-=+/%*]
op_relacional [+-]i?q|":i"|"d/i"
op_aritmetico "&&*"|"&%&"|"&*&"|"&+"|"&-"|"&*"|"&/"
sim_especial "@>"|"$$"|"#?"|"::="|"?="|"%~"|"+"

%%

 /* Los delimitadores no generan tokens. Flex actualiza yylineno. */
[ \t\r\n]+  { }

 /* Se descarta el comentario de linea sin consumir el salto final. */
"//"[^\n]*  { }

 /* Mientras este activo COMENTARIO no se reconocen las otras clases. */
"/*" {
    lineaComentario = yylineno;
    BEGIN(COMENTARIO);
}
<COMENTARIO>"*/"          { BEGIN(INITIAL); }
<COMENTARIO>[^*\n]+       { }
<COMENTARIO>"*"           { }
<COMENTARIO>\n            { }
<COMENTARIO><<EOF>> {
    informarError(lineaComentario, "comentario sin cerrar.");
    return 0;
}

 /* Las clases de catalogo conservan sus indices aunque cambie el orden de entrada. */
{reservada} {
    registrarCatalogo(PALABRA_RESERVADA, reservadas, CANTIDAD(reservadas));
}
{op_asignacion} {
    registrarCatalogo(ASIGNACION, asignacion, CANTIDAD(asignacion));
}
{op_relacional} {
    registrarCatalogo(RELACIONAL, relacionales, CANTIDAD(relacionales));
}
{op_aritmetico} {
    registrarCatalogo(ARITMETICO, aritmeticos, CANTIDAD(aritmeticos));
}
{sim_especial} {
    registrarCatalogo(ESPECIAL, especiales, CANTIDAD(especiales));
}

 /* Un identificador largo se reporta completo y no se inserta en la tabla. */
{identificador} {
    if (yyleng > LONGITUD_IDENTIFICADOR) {
        informarError(yylineno, "identificador de mas de 32 caracteres.");
    } else {
        agregarToken(IDENTIFICADOR, buscarOInsertarSimbolo(yytext));
    }
}
"I__I" {
    informarError(yylineno, "identificador con cuerpo vacio.");
}

 /* La regla valida va primero para ganar empates con la regla de error. */
{entero} {
    registrarEntero();
}
[pn]?{digito}+i {
    informarError(yylineno, "entero invalido: use 0i o p/n y digitos sin cero inicial.");
}
{real} {
    agregarToken(REAL, insertarReal(yytext));
}

 /* Cada aparicion se inserta; los delimitadores no forman parte del dato. */
{cadena} {
    agregarToken(CADENA, insertarCadena(yytext + 1, (size_t)yyleng - 2));
}

 /* Se recupera al cierre de la cadena o antes del siguiente salto de linea.
  * Estas reglas van despues de la valida; no generan tokens parciales. */
"<"[^>\n]*">" {
    informarError(yylineno, "cadena con caracteres fuera del intervalo ASCII 32..126.");
}
"<"[^>\n]* {
    informarError(yylineno, "cadena sin cerrar antes del fin de linea o archivo.");
}
"*/" {
    informarError(yylineno, "cierre de comentario sin apertura.");
}

 /* Un caracter desconocido se consume para poder continuar con la entrada. */
. {
    fprintf(stderr, "Linea %d: caracter no reconocido (byte 0x%02X).\n",
            yylineno, (unsigned int)(unsigned char)yytext[0]);
    cantidadErrores++;
}
<<EOF>>  { return 0; }

%%

/* Busca el valor fijo del lexema y lo agrega a la secuencia de tokens. */
static void registrarCatalogo(int clase, const char *const catalogo[], int cantidad)
{
    int posicion;

    posicion = buscarCatalogo(yytext, catalogo, cantidad);
    if (posicion < 0) {
        fprintf(stderr, "Error interno: lexema ausente de su catalogo.\n");
        exit(2);
    }
    agregarToken(clase, posicion);
}

/* Traduce p/n al signo y convierte con comprobacion de rango.
 * yytext puede modificarse durante esta accion; despues Flex lo reutiliza. */
static void registrarEntero(void)
{
    long valor;
    char *fin;

    if (strcmp(yytext, "0i") == 0) {
        agregarToken(ENTERO, 0);
        return;
    }
    yytext[0] = yytext[0] == 'n' ? '-' : '+';
    yytext[yyleng - 1] = '\0';
    errno = 0;
    valor = strtol(yytext, &fin, 10);
    if (errno == ERANGE || *fin != '\0' || valor < INT_MIN || valor > INT_MAX) {
        informarError(yylineno, "constante entera fuera del rango de int.");
        return;
    }
    agregarToken(ENTERO, (int)valor);
}

/* Registra un error lexico sin detener el reconocimiento de los demas tokens. */
static void informarError(int linea, const char *mensaje)
{
    fprintf(stderr, "Linea %d: %s\n", linea, mensaje);
    cantidadErrores++;
}

/* Se ejecuta al terminar normalmente o al salir por un fallo de memoria.
 * Cierra el archivo, libera el buffer de Flex y despues nuestras tablas. */
static void liberarRecursos(void)
{
    if (yyin != NULL) {
        fclose(yyin);
        yyin = NULL;
    }
    yylex_destroy();
    liberarTablas();
}

/* Recibe un archivo fuente, realiza el analisis y muestra los resultados. */
int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Uso: %s archivo_fuente\n", argv[0]);
        return 2;
    }
    if (atexit(liberarRecursos) != 0) {
        fprintf(stderr, "Error: no se pudo preparar la liberacion de recursos.\n");
        return 2;
    }
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        perror(argv[1]);
        return 2;
    }
    yylex();
    mostrarResultados();
    printf("\nErrores lexicos: %lu\n", cantidadErrores);
    if (fflush(stdout) == EOF) {
        fprintf(stderr, "Error: no se pudo escribir la salida.\n");
        return 2;
    }
    return cantidadErrores == 0 ? 0 : 1;
}
