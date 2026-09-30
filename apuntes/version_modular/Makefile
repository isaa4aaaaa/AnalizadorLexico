CC = gcc
FLEX = flex
CFLAGS = -std=c90 -Wall -Wextra -pedantic-errors -O2

.PHONY: all probar

all: analizador

lex.yy.c: analizador.l
	$(FLEX) -o $@ $<

analizador: lex.yy.c tablas.c tablas.h
	$(CC) $(CFLAGS) lex.yy.c tablas.c -o $@

probar: analizador
	python3 pruebas/probar.py ./analizador
