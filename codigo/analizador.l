%{
/*
 * Analizador lexico de las nueve clases definidas en el enunciado.
 * Autores: Isaac Campos, Benyy Arriaga.
 * Fecha de realizacion: 26 Septiembre 2026
 */

/* 1. Definiciones: bibliotecas, estructuras y tablas. */

/* Bibliotecas */
#include <errno.h>  /* errno y ERANGE para revisar la conversion de enteros. */
#include <limits.h> /* Limites INT_MIN e INT_MAX. */
#include <stdio.h>  /* Lectura de archivos y salida a pantalla. */
#include <stdlib.h> /* Memoria dinamica, strtol y salida del programa. */
#include <string.h> /* Comparar, medir y copiar texto. */

/* Tipos de datos */

/* Los numeros de clase corresponden a lo definido en clase. */
enum ClaseToken {
    PALABRA_RESERVADA = 0, /* Palabras del catalogo, como int y mostrar. */
    IDENTIFICADOR = 1,     /* Nombres delimitados por I_ y _I. */
    ASIGNACION = 2,        /* Operadores para asignar valores, como :=. */
    RELACIONAL = 3,        /* Operadores de comparacion, como +q. */
    ARITMETICO = 4,        /* Operadores de calculo, como &+ y &*. */
    ESPECIAL = 5,          /* Signos del catalogo, como $$ y #?. */
    ENTERO = 6,            /* Numero entero; el token guarda su valor. */
    REAL = 7,             /* Numero decimal o cientifico; se guarda su texto. */
    CADENA = 8            /* Texto delimitado por < y >. */
};

/* El valor contiene un indice, excepto en enteros, donde contiene el numero. */
typedef struct {
    int clase;
    int valor;
} Token;

/* Cada simbolo conserva su nombre y el tipo inicial solicitado. */
typedef struct {
    int posicion;
    char *nombre;
    int tipo; /* Queda en -1; el analizador lexico no decide el tipo. */
} Simbolo;

/* Reales y cadenas usan este mismo registro, pero se guardan en tablas distintas. */
typedef struct {
    int posicion;
    char *dato;
} Literal;

/* Cada tabla crece conforme se agregan elementos. Cantidad indica cuantos se usan. */
typedef struct {
    Literal *elementos;
    int cantidad;
    int capacidad;
} TablaLiterales;

/* Constantes y macro */
/* Primer espacio reservado en cada arreglo; despues se duplica si se llena. */
#define CAPACIDAD_INICIAL 16
/* Maximo de caracteres del nombre completo, incluyendo I_ y _I (enunciado, p. 1). */
#define LONGITUD_IDENTIFICADOR 32

/* sizeof da bytes; al dividir entre el tamano de una entrada obtenemos la cantidad.
 * Se usa para saber cuantas entradas buscar en cada catalogo.
 * Solo sirve con arreglos completos, no con apuntadores recibidos en funciones. */
#define CANTIDAD(arreglo) ((int)(sizeof(arreglo) / sizeof((arreglo)[0])))

/* Variables de las tablas
 * static limita estas variables a este archivo. Las acciones y funciones las comparten.
 * NULL indica que todavia no se ha reservado el arreglo. */
static Token *tokens = NULL;
static int cantidadTokens = 0;
static int capacidadTokens = 0;
static Simbolo *simbolos = NULL;
static int cantidadSimbolos = 0;
static int capacidadSimbolos = 0;
/* Los tres valores iniciales son: apuntador, cantidad y capacidad. */
static TablaLiterales reales = {NULL, 0, 0};
static TablaLiterales cadenas = {NULL, 0, 0};

/* Catalogos
 * Los indices son los valores del enunciado. const evita cambiar los textos
 * y los apuntadores que guardan los catalogos. */
static const char *const reservadas[] = {
    "bool", "cad", "cte", "def", "decisión", "elegir", "flot", "fls", "haz",
    "if", "int", "leer", "mientras", "mostrar", "para", "regresa", "vdd"
};
static const char *const asignacion[] = {":=", ":+", ":-", ":*", ":/", ":%"};
static const char *const relacionales[] = {"+q", "-q", "+iq", "-iq", ":i", "d/i"};
static const char *const aritmeticos[] = {"&+", "&-", "&*", "&/", "&&*", "&%&", "&*&"};
static const char *const especiales[] = {"@>", "$$", "#?", "::=", "?=", "%~", "+"};

/* Control de errores y comentarios */
/* unsigned long cuenta errores sin signo. Se imprime con %lu. */
static unsigned long cantidadErrores = 0;
static int lineaComentario = 1;

/* Declaraciones de funciones: permiten llamarlas antes de escribir su cuerpo. */
static void agregarToken(int clase, int valor);
static int buscarCatalogo(const char *texto, const char *const catalogo[], int cantidad);
static int buscarOInsertarSimbolo(const char *nombre);
static int insertarReal(const char *texto);
static int insertarCadena(const char *texto, size_t longitud);
static void mostrarResultados(void);
static void liberarTablas(void);
static void registrarCatalogo(int clase, const char *const catalogo[], int cantidad);
static void registrarEntero(void);
static void informarError(int linea, const char *mensaje);
static void liberarRecursos(void);
%}

 /* Opciones de Flex 
  * yylineno cuenta los saltos para indicar la linea de los errores.
  * noinput y nounput omiten funciones de lectura y devolucion de caracteres que no usamos.
  * never-interactive evita consultar si la entrada es una terminal; leemos archivos.
  * nounistd omite unistd.h. Junto con la anterior evita depender de llamadas POSIX.
  * nodefault quita el eco automatico: las reglas de abajo se encargan de cada byte.
  * Son opciones del generador; el codigo C se compila como C90.
  * yywrap lo proporciona la biblioteca enlazada con -lfl. */
%option yylineno noinput nounput never-interactive nounistd nodefault
 /* Estado para comentarios de bloque.
  * %x hace que solo se apliquen las reglas marcadas COMENTARIO mientras este activo.
  * BEGIN lo activa al abrir el bloque y vuelve a INITIAL al encontrar el primer cierre.
  * Asi el contenido no genera tokens y se puede avisar si el archivo termina sin cierre.*/
%x COMENTARIO

 /* Expresiones regulares. */

 /* Un digito entre cero y nueve. */
digito [0-9]

 /* Se reconocen identificadores completos antes de revisar su longitud.
  * El cuerpo no puede estar vacio y puede contener guiones bajos. */
identificador "I_"[A-Za-z0-9_]+"_I"

 /* Cero solo, o p/n seguido de un primer digito no nulo y los demas digitos. */
entero 0i|[pn][1-9]{digito}*i

 /* Punto obligatorio, con uno o mas digitos a la derecha. Acepta .24. */
decimal {digito}*[.]{digito}+

 /* e o E, menos opcional y al menos un digito para el exponente. */
exponente [eE]-?{digito}+

 /* Menos opcional; decimal con exponente opcional, o entero con exponente obligatorio. */
real -?({decimal}({exponente})?|{digito}+{exponente})

 /* Los rangos hexadecimales cubren ASCII 32..61 y 63..126: excluyen > (62).
  * Se admite < interno. El * permite contenido vacio, como pide el enunciado (p. 1). */
cadena "<"[\x20-\x3D\x3F-\x7E]*">"

 /* Coincide con cualquiera de las 17 palabras, con su escritura exacta. */
reservada "bool"|"cad"|"cte"|"def"|"decisión"|"elegir"|"flot"|"fls"|"haz"|"if"|"int"|"leer"|"mientras"|"mostrar"|"para"|"regresa"|"vdd"

 /* Dos puntos seguidos de un signo del catalogo. El guion inicial es literal. */
op_asignacion ":"[-=+/%*]

 /* Mas o menos, i opcional y q; tambien los lexemas :i y d/i. */
op_relacional [+-]i?q|":i"|"d/i"

 /* Las comillas hacen literales los signos de cada operador aritmetico. */
op_aritmetico "&&*"|"&%&"|"&*&"|"&+"|"&-"|"&*"|"&/"

 /* Cada alternativa es un simbolo especial completo del catalogo. */
sim_especial "@>"|"$$"|"#?"|"::="|"?="|"%~"|"+"

%%

 /* 2. Reglas: texto reconocido y accion que se realiza.
  * Flex elige la coincidencia mas larga; si empatan, la primera regla. */

 /* Delimitadores y comentarios */
 /* Uno o mas espacios, tabuladores o saltos de linea.
  * Las llaves vacias descartan el texto. Flex actualiza yylineno. */
[ \t\n]+  { }

 /* Dos barras y cualquier contenido hasta antes de \n; tambien acepta // solo. */
"//"[^\n]*  { }

 /* Mientras este activo COMENTARIO no se reconocen las otras clases. */
"/*" {
    lineaComentario = yylineno;
    BEGIN(COMENTARIO);
}
<COMENTARIO>"*/"          { BEGIN(INITIAL); }
 /* Se consume texto que no sea asterisco ni salto para no saltarse el cierre. */
<COMENTARIO>[^*\n]+       { }
 /* Un asterisco aislado y los saltos tambien se descartan. */
<COMENTARIO>"*"           { }
<COMENTARIO>\n            { }
 /* EOF significa fin de archivo. Si seguimos en este estado, falto el cierre. */
<COMENTARIO><<EOF>> {
    informarError(lineaComentario, "comentario sin cerrar.");
    return 0;
}

 /* Clases de catalogo: sus indices no dependen del orden de entrada. */
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

 /* Identificadores */
 /* Un identificador largo se reporta completo y no se inserta en la tabla. */
{identificador} {
    if (yyleng > LONGITUD_IDENTIFICADOR) {
        informarError(yylineno, "identificador de mas de 32 caracteres.");
    } else {
        agregarToken(IDENTIFICADOR, buscarOInsertarSimbolo(yytext));
    }
}
 /* Prefijo y sufijo sin ningun caracter en el cuerpo. */
"I__I" {
    informarError(yylineno, "identificador con cuerpo vacio.");
}

 /* Numeros */
 /* La regla valida va primero para ganar empates con la regla de error. */
{entero} {
    registrarEntero();
}
 /* Esta forma mas amplia recoge enteros invalidos como p0i, n01i o 25i. */
[pn]?{digito}+i {
    informarError(yylineno, "entero invalido: use 0i o p/n y digitos sin cero inicial.");
}
{real} {
    agregarToken(REAL, insertarReal(yytext));
}

 /* Cadenas */
 /* Cada aparicion se inserta; los delimitadores no forman parte del dato. */
{cadena} {
    /* +1 salta el < y -2 excluye ambos delimitadores. yyleng es la longitud leida. */
    agregarToken(CADENA, insertarCadena(yytext + 1, (size_t)yyleng - 2));
}

 /* Una cadena con cierre que no paso la regla valida tiene contenido prohibido. */
"<"[^>\n]*">" {
    informarError(yylineno, "cadena con caracteres fuera del intervalo ASCII 32..126.");
}
 /* Si falta >, se consume hasta antes del salto o hasta el final del archivo. */
"<"[^>\n]* {
    informarError(yylineno, "cadena sin cerrar antes del fin de linea o archivo.");
}
 /* Otros errores y fin de archivo */
 /* El cierre de bloque solo es valido dentro del estado COMENTARIO. */
"*/" {
    informarError(yylineno, "cierre de comentario sin apertura.");
}

 /* El punto recoge un byte sin regla, excepto \n, que ya se cubrio arriba. */
. {
    /* unsigned char evita interpretar el byte como negativo; unsigned int es
     * el tipo que espera %X. 02 muestra al menos dos cifras hexadecimales. */
    fprintf(stderr, "Linea %d: caracter no reconocido (byte 0x%02X).\n",
            yylineno, (unsigned int)(unsigned char)yytext[0]);
    cantidadErrores++;
}
 /* Final normal: volver a main para mostrar las tablas. */
<<EOF>>  { return 0; }

%%

/* 3. Funciones en C. */

/* Reserva y copia de memoria */

/* Detiene el programa cuando no se puede seguir almacenando informacion.
 * La limpieza registrada por main se ejecuta tambien al llamar a exit. */

static void errorMemoria(void)
{
    fprintf(stderr, "Error: no se puede reservar mas memoria para las tablas.\n");
    exit(2);
}

/* Recibe el arreglo, cantidad usada, direccion de su capacidad y bytes por entrada.
 * Devuelve el apuntador al arreglo con espacio disponible y actualiza la capacidad.
 * void * permite usar la misma funcion con las distintas tablas. */

static void *asegurarEspacio(void *elementos, int cantidad, int *capacidad, size_t tamElemento)
{
    int nuevaCapacidad;
    void *nuevo;

    if (cantidad < *capacidad) {
        return elementos;
    }
    if (*capacidad > INT_MAX / 2) {
        errorMemoria();
    }
    if (*capacidad == 0) {
        nuevaCapacidad = CAPACIDAD_INICIAL;
    } else {
        nuevaCapacidad = *capacidad * 2;
    }
    /* size_t es el tipo sin signo para tamanos en bytes. (size_t)-1 es su maximo.
     * La division comprueba el limite antes de multiplicar y reservar. */
    if ((size_t)nuevaCapacidad > (size_t)-1 / tamElemento) {
        errorMemoria();
    }
    /* El temporal conserva el bloque anterior si realloc falla. */
    nuevo = realloc(elementos, (size_t)nuevaCapacidad * tamElemento);
    if (nuevo == NULL) {
        errorMemoria();
    }
    *capacidad = nuevaCapacidad;
    return nuevo;
}

/* Recibe texto y cuantos bytes copiar. Devuelve una copia antes de que cambie yytext.
 * Agrega '\0' al final. La copia se libera junto con su tabla. */

static char *copiarTexto(const char *texto, size_t longitud)
{
    char *copia;

    if (longitud == (size_t)-1) {
        errorMemoria();
    }
    copia = malloc(longitud + 1);
    if (copia == NULL) {
        errorMemoria();
    }
    memcpy(copia, texto, longitud);
    copia[longitud] = '\0';
    return copia;
}

/* Busqueda e insercion en las tablas */

/* Recibe la clase y su valor. Agrega el token al final de la secuencia. */

static void agregarToken(int clase, int valor)
{
    tokens = asegurarEspacio(tokens, cantidadTokens, &capacidadTokens, sizeof *tokens);
    tokens[cantidadTokens].clase = clase;
    tokens[cantidadTokens].valor = valor;
    cantidadTokens++;
}

/* Recibe el texto, el catalogo y su cantidad de entradas.
 * Devuelve el indice del texto, o -1 si no lo encuentra. */

static int buscarCatalogo(const char *texto, const char *const catalogo[], int cantidad)
{
    int posicion;

    for (posicion = 0; posicion < cantidad; posicion++) {
        /* strcmp devuelve cero cuando el contenido de ambas cadenas es igual. */
        if (strcmp(texto, catalogo[posicion]) == 0) {
            return posicion;
        }
    }
    return -1;
}

/* Recibe el nombre completo y devuelve su posicion en simbolos.
 * Busca uno por uno; si no existe lo inserta con tipo -1. */

static int buscarOInsertarSimbolo(const char *nombre)
{
    int posicion;

    for (posicion = 0; posicion < cantidadSimbolos; posicion++) {
        if (strcmp(nombre, simbolos[posicion].nombre) == 0) {
            return posicion;
        }
    }
    simbolos = asegurarEspacio(simbolos, cantidadSimbolos, &capacidadSimbolos, sizeof *simbolos);
    posicion = cantidadSimbolos;
    simbolos[posicion].nombre = copiarTexto(nombre, strlen(nombre));
    simbolos[posicion].posicion = posicion;
    simbolos[posicion].tipo = -1;
    cantidadSimbolos++;
    return posicion;
}

/* Recibe la tabla, el texto y su longitud. Inserta sin buscar duplicados
 * y devuelve la nueva posicion, como pide la tarea. */

static int insertarLiteral(TablaLiterales *tabla, const char *texto, size_t longitud)
{
    int posicion;

    /* tabla apunta a reales o cadenas. -> accede a sus campos y permite cambiarlos. */
    tabla->elementos = asegurarEspacio(tabla->elementos, tabla->cantidad, &tabla->capacidad, sizeof *tabla->elementos);
    posicion = tabla->cantidad;
    tabla->elementos[posicion].dato = copiarTexto(texto, longitud);
    tabla->elementos[posicion].posicion = posicion;
    tabla->cantidad++;
    return posicion;
}

/* Recibe el texto del real, lo guarda tal cual y devuelve su posicion. */

static int insertarReal(const char *texto)
{
    return insertarLiteral(&reales, texto, strlen(texto));
}

/* Recibe contenido sin delimitadores y su longitud. Devuelve su posicion en cadenas. */

static int insertarCadena(const char *texto, size_t longitud)
{
    return insertarLiteral(&cadenas, texto, longitud);
}

/* Salida y liberacion de tablas */

/* Recibe el titulo y la tabla que se va a imprimir, sin cambiarla.
 * Las comillas permiten ver las cadenas vacias. */

static void mostrarLiterales(const char *titulo, const TablaLiterales *tabla)
{
    int posicion;

    printf("\n%s\nPosicion\tDato\n", titulo);
    for (posicion = 0; posicion < tabla->cantidad; posicion++) {
        printf("%d\t\"%s\"\n", tabla->elementos[posicion].posicion,
               tabla->elementos[posicion].dato);
    }
}

/* Usa las tablas globales para imprimirlas junto con los tokens en orden de entrada. */

static void mostrarResultados(void)
{
    int posicion;

    printf("TABLA DE SIMBOLOS\nPosicion\tNombre\tTipo\n");
    for (posicion = 0; posicion < cantidadSimbolos; posicion++) {
        printf("%d\t%s\t%d\n", simbolos[posicion].posicion,
               simbolos[posicion].nombre, simbolos[posicion].tipo);
    }
    mostrarLiterales("LITERALES REALES", &reales);
    mostrarLiterales("LITERALES CADENA", &cadenas);
    printf("\nSECUENCIA DE TOKENS\n");
    for (posicion = 0; posicion < cantidadTokens; posicion++) {
        printf("(%d,%d)\n", tokens[posicion].clase, tokens[posicion].valor);
    }
}

/* Libera primero las cadenas de cada entrada y despues los arreglos.
 * Los catalogos fijos y yytext no pertenecen a estas tablas. */

static void liberarTablas(void)
{
    int posicion;

    for (posicion = 0; posicion < cantidadSimbolos; posicion++) {
        free(simbolos[posicion].nombre);
    }
    for (posicion = 0; posicion < reales.cantidad; posicion++) {
        free(reales.elementos[posicion].dato);
    }
    for (posicion = 0; posicion < cadenas.cantidad; posicion++) {
        free(cadenas.elementos[posicion].dato);
    }
    free(simbolos);
    free(reales.elementos);
    free(cadenas.elementos);
    free(tokens);
    simbolos = NULL;
    tokens = NULL;
    cantidadSimbolos = capacidadSimbolos = 0;
    cantidadTokens = capacidadTokens = 0;
    reales.elementos = cadenas.elementos = NULL;
    reales.cantidad = reales.capacidad = 0;
    cadenas.cantidad = cadenas.capacidad = 0;
}

/* Funciones que usan las acciones de Flex y manejo de errores. */

/* Recibe la clase, su catalogo y cantidad de entradas.
 * Busca yytext en ese catalogo y agrega el token con su indice. */

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

/* Usa yytext y yyleng de la regla actual; agrega el entero o informa un error.
 * Traduce p/n al signo y convierte con comprobacion de rango.
 * yytext puede modificarse durante esta accion; despues Flex lo reutiliza. */

static void registrarEntero(void)
{
    long valor;
    char *fin;

    if (strcmp(yytext, "0i") == 0) {
        agregarToken(ENTERO, 0);
        return;
    }
    if (yytext[0] == 'n') {
        yytext[0] = '-';
    } else {
        yytext[0] = '+';
    }
    yytext[yyleng - 1] = '\0';
    /* Se reinicia errno para no arrastrar un error anterior. strtol deja en fin
     * la direccion del primer caracter que no pudo convertir. ERANGE indica
     * que no cabe en long; tambien se comprueban los limites del campo int. */
    errno = 0;
    valor = strtol(yytext, &fin, 10);
    if (errno == ERANGE || *fin != '\0' || valor < INT_MIN || valor > INT_MAX) {
        informarError(yylineno, "constante entera fuera del rango de int.");
        return;
    }
    agregarToken(ENTERO, (int)valor);
}

/* Recibe la linea y el mensaje; muestra el error y aumenta el contador. */

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

/* Inicio del programa */

/* argc indica cuantos argumentos hay y argv contiene sus textos.
 * Abre argv[1], analiza y muestra resultados. Devuelve 0 si todo fue valido,
 * 1 si hubo errores lexicos o 2 si no se pudo completar la ejecucion. */

int main(int argc, char *argv[])
{
    /* argc cuenta tambien el nombre del ejecutable; argv[1] es el archivo. */
    if (argc != 2) {
        fprintf(stderr, "Uso: %s archivo_fuente\n", argv[0]);
        return 2;
    }
    /* atexit registra la limpieza para el final, incluso si otra funcion usa exit. */
    if (atexit(liberarRecursos) != 0) {
        fprintf(stderr, "Error: no se pudo preparar la liberacion de recursos.\n");
        return 2;
    }
    /* yyin es el archivo que Flex lee. El modo r lo abre solo para lectura. */
    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        perror(argv[1]);
        return 2;
    }
    /* Flex genera yylex. Sus acciones van llenando las tablas hasta llegar a EOF. */
    yylex();
    mostrarResultados();
    printf("\nErrores lexicos: %lu\n", cantidadErrores);
    if (fflush(stdout) == EOF) {
        fprintf(stderr, "Error: no se pudo escribir la salida.\n");
        return 2;
    }
    if (cantidadErrores == 0) {
        return 0;
    }
    return 1;
}
