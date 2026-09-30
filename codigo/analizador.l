%{
/*
 * Analizador lexico de las nueve clases definidas en el enunciado.
 * Autores: Isaac Campos, Benyy Arriaga.
 * Fecha de realizacion: 27 Septiembre 2026
 */

/* 1. Definiciones: bibliotecas, estructuras y tablas. */

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

#define CAPACIDAD_INICIAL 16
#define LONGITUD_IDENTIFICADOR 32

/* sizeof da bytes; al dividir entre el tamano de una entrada obtenemos la cantidad.
 * Esta macro se usa con arreglos completos, no con apuntadores recibidos en funciones. */
#define CANTIDAD(arreglo) ((int)(sizeof(arreglo) / sizeof((arreglo)[0])))

/* Cada tabla crece conforme se agregan elementos. Cantidad indica cuantos se usan. */
typedef struct {
    Literal *elementos;
    int cantidad;
    int capacidad;
} TablaLiterales;

/* static limita estas variables a este archivo. Las acciones y funciones las comparten.
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

/* Los indices son los valores del enunciado. const evita cambiar los textos
 * y los apuntadores que guardan los catalogos. */
static const char *const reservadas[] = {
    "bool", "cad", "cte", "def", "decisión", "elegir", "flot", "fls", "haz",
    "if", "int", "leer", "mientras", "mostrar", "para", "regresa", "vdd"
};
static const char *const asignacion[] = {":=", ":+", ":-", ":*", ":/", ":%"};
static const char *const relacionales[] = {"+q", "-q", "+iq", "-iq", ":i", "d/i"};
static const char *const aritmeticos[] = {"&+", "&-", "&*", "&/", "&&*", "&%&", "&*&"};
static const char *const especiales[] = {"@>", "$$", "#?", "::=", "?=", "%~", "+"};

/* unsigned long cuenta errores sin signo. Se imprime con %lu. */
static unsigned long cantidadErrores = 0;
static int lineaComentario = 1;

/* Estas declaraciones permiten usar las funciones antes de escribir su cuerpo. */
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

 /* Opciones de Flex: yylineno cuenta lineas; noinput y nounput omiten funciones
  * que no usamos. never-interactive y nounistd permiten leer archivos sin POSIX.
  * nodefault evita el eco de caracteres desconocidos. yywrap lo proporciona -lfl. */
%option yylineno noinput nounput never-interactive nounistd nodefault
 /* Estado exclusivo: mientras esta activo solo se aplican las reglas COMENTARIO. */
%x COMENTARIO

 /* Expresiones regulares. Los nombres entre llaves reutilizan otra expresion. */
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
  * Se admite < interno. El asterisco permite que el contenido este vacio. */
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

 /* Uno o mas espacios, tabuladores o saltos. \r permite archivos de Windows.
  * Las llaves vacias descartan el texto. Flex actualiza yylineno. */
[ \t\r\n]+  { }

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
 /* Prefijo y sufijo sin ningun caracter en el cuerpo. */
"I__I" {
    informarError(yylineno, "identificador con cuerpo vacio.");
}

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

/* 3. Funciones en C. Primero se manejan memoria y tablas. */

/* Detiene el programa cuando no se puede seguir almacenando informacion.
 * La limpieza registrada por main se ejecuta tambien al llamar a exit. */
static void errorMemoria(void)
{
    fprintf(stderr, "Error: no se puede reservar mas memoria para las tablas.\n");
    exit(2);
}

/* Amplia un arreglo solo cuando esta lleno. El apuntador temporal conserva
 * el bloque original si realloc falla. void * permite usarla con las distintas
 * estructuras; tamElemento indica los bytes de cada entrada. Se recibe la
 * direccion de capacidad para poder actualizarla en la tabla original. */
static void *asegurarEspacio(void *elementos, int cantidad, int *capacidad,
                            size_t tamElemento)
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
    nuevo = realloc(elementos, (size_t)nuevaCapacidad * tamElemento);
    if (nuevo == NULL) {
        errorMemoria();
    }
    *capacidad = nuevaCapacidad;
    return nuevo;
}

/* Crea una copia propia antes de que Flex reutilice yytext.
 * El byte adicional guarda '\0', que marca el final de la cadena en C. */
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

/* Agrega un token al final, conservando el orden del archivo de entrada. */
static void agregarToken(int clase, int valor)
{
    tokens = asegurarEspacio(tokens, cantidadTokens, &capacidadTokens,
                            sizeof *tokens);
    tokens[cantidadTokens].clase = clase;
    tokens[cantidadTokens].valor = valor;
    cantidadTokens++;
}

/* Busca por contenido y devuelve el indice del catalogo, o -1 si no existe. */
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

/* Reutiliza la posicion si el identificador ya existe.
 * La busqueda es lineal; solo se inserta cuando no se encuentra el nombre. */
static int buscarOInsertarSimbolo(const char *nombre)
{
    int posicion;

    for (posicion = 0; posicion < cantidadSimbolos; posicion++) {
        if (strcmp(nombre, simbolos[posicion].nombre) == 0) {
            return posicion;
        }
    }
    simbolos = asegurarEspacio(simbolos, cantidadSimbolos, &capacidadSimbolos,
                              sizeof *simbolos);
    posicion = cantidadSimbolos;
    simbolos[posicion].nombre = copiarTexto(nombre, strlen(nombre));
    simbolos[posicion].posicion = posicion;
    simbolos[posicion].tipo = -1;
    cantidadSimbolos++;
    return posicion;
}

/* Inserta una aparicion de un literal sin buscar duplicados, como pide la tarea. */
static int insertarLiteral(TablaLiterales *tabla, const char *texto, size_t longitud)
{
    int posicion;

    /* tabla apunta a reales o cadenas. -> accede a sus campos y permite cambiarlos. */
    tabla->elementos = asegurarEspacio(tabla->elementos, tabla->cantidad,
                                      &tabla->capacidad, sizeof *tabla->elementos);
    posicion = tabla->cantidad;
    tabla->elementos[posicion].dato = copiarTexto(texto, longitud);
    tabla->elementos[posicion].posicion = posicion;
    tabla->cantidad++;
    return posicion;
}

/* Guarda la representacion exacta del real, sin convertirla a punto flotante. */
static int insertarReal(const char *texto)
{
    return insertarLiteral(&reales, texto, strlen(texto));
}

/* Guarda solo el contenido que la regla de Flex separo de los delimitadores. */
static int insertarCadena(const char *texto, size_t longitud)
{
    return insertarLiteral(&cadenas, texto, longitud);
}

/* Muestra una tabla de literales. Las comillas hacen visibles los datos vacios. */
static void mostrarLiterales(const char *titulo, const TablaLiterales *tabla)
{
    int posicion;

    printf("\n%s\nPosicion\tDato\n", titulo);
    for (posicion = 0; posicion < tabla->cantidad; posicion++) {
        printf("%d\t\"%s\"\n", tabla->elementos[posicion].posicion,
               tabla->elementos[posicion].dato);
    }
}

/* Imprime las tres tablas y despues todos los tokens en orden de aparicion. */
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

/* Funcion principal: recibe el archivo, analiza y muestra los resultados. */
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
