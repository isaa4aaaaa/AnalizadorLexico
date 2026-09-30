/*
 * Programa encargado de guardar simbolos, literales y la secuencia de tokens.
 * Autores: Isaac Campos, Benyy Arriaga.
 * Fecha de realizacion: 29 Septiembre 2026
 */

#include "tablas.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CAPACIDAD_INICIAL 16

/* Cada tabla crece conforme se agregan elementos. Cantidad indica cuantos se usan. */
typedef struct {
    Literal *elementos;
    int cantidad;
    int capacidad;
} TablaLiterales;

static Token *tokens = NULL;
static int cantidadTokens = 0;
static int capacidadTokens = 0;
static Simbolo *simbolos = NULL;
static int cantidadSimbolos = 0;
static int capacidadSimbolos = 0;
static TablaLiterales reales = {NULL, 0, 0};
static TablaLiterales cadenas = {NULL, 0, 0};

/* Detiene el programa cuando no se puede seguir almacenando informacion.
 * La limpieza registrada por main se ejecuta tambien al llamar a exit. */
static void errorMemoria(void)
{
    fprintf(stderr, "Error: no se puede reservar mas memoria para las tablas.\n");
    exit(2);
}

/* Amplia un arreglo solo cuando esta lleno. El apuntador temporal conserva
 * el bloque original si realloc falla. Se revisa el tamano antes de multiplicar. */
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
    nuevaCapacidad = *capacidad == 0 ? CAPACIDAD_INICIAL : *capacidad * 2;
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
 * El byte adicional guarda el terminador de la cadena, incluso si esta vacia. */
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
void agregarToken(int clase, int valor)
{
    tokens = asegurarEspacio(tokens, cantidadTokens, &capacidadTokens,
                            sizeof *tokens);
    tokens[cantidadTokens].clase = clase;
    tokens[cantidadTokens].valor = valor;
    cantidadTokens++;
}

/* Busca por contenido y devuelve el indice del catalogo, o -1 si no existe. */
int buscarCatalogo(const char *texto, const char *const catalogo[], int cantidad)
{
    int posicion;

    for (posicion = 0; posicion < cantidad; posicion++) {
        if (strcmp(texto, catalogo[posicion]) == 0) {
            return posicion;
        }
    }
    return -1;
}

/* Reutiliza la posicion si el identificador ya existe.
 * La busqueda es lineal; solo se inserta cuando no se encuentra el nombre. */
int buscarOInsertarSimbolo(const char *nombre)
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

    tabla->elementos = asegurarEspacio(tabla->elementos, tabla->cantidad,
                                      &tabla->capacidad, sizeof *tabla->elementos);
    posicion = tabla->cantidad;
    tabla->elementos[posicion].dato = copiarTexto(texto, longitud);
    tabla->elementos[posicion].posicion = posicion;
    tabla->cantidad++;
    return posicion;
}

/* Guarda la representacion exacta del real, sin convertirla a punto flotante. */
int insertarReal(const char *texto)
{
    return insertarLiteral(&reales, texto, strlen(texto));
}

/* Guarda solo el contenido que la regla de Flex separo de los delimitadores. */
int insertarCadena(const char *texto, size_t longitud)
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
void mostrarResultados(void)
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
void liberarTablas(void)
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
