/*
 * Definiciones y operaciones de las tablas del analizador lexico.
 * Autores: Isaac Campos, Benyy Arriaga.
 * Fecha de realizacion: 29 Septiembre 2026
 */

#ifndef TABLAS_H
#define TABLAS_H

#include <stddef.h>

/* Los numeros de clase corresponden al enunciado y no cambian. */
enum ClaseToken {
    PALABRA_RESERVADA = 0,
    IDENTIFICADOR = 1,
    ASIGNACION = 2,
    RELACIONAL = 3,
    ARITMETICO = 4,
    ESPECIAL = 5,
    ENTERO = 6,
    REAL = 7,
    CADENA = 8
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
    int tipo;
} Simbolo;

/* Reales y cadenas usan este mismo registro, pero se guardan en tablas distintas. */
typedef struct {
    int posicion;
    char *dato;
} Literal;

void agregarToken(int clase, int valor);
int buscarCatalogo(const char *texto, const char *const catalogo[], int cantidad);
int buscarOInsertarSimbolo(const char *nombre);
int insertarReal(const char *texto);
int insertarCadena(const char *texto, size_t longitud);
void mostrarResultados(void);
void liberarTablas(void);

#endif
