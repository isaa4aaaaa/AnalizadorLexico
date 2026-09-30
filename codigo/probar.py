#!/usr/bin/env python3

# Pruebas de reconocimiento, tablas y recuperacion del analizador.
# Autores: Isaac Campos, Benyy Arriaga.
# Fecha de realizacion: 29 Septiembre 2026

import ctypes
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


EJECUTABLE = str(Path(sys.argv.pop(1) if len(sys.argv) > 1 else './analizador').resolve())
EJEMPLOS = Path(__file__).resolve().parent / 'ejemplos'


class PruebasAnalizador(unittest.TestCase):

    # Cada entrada se guarda en un archivo temporal y se ejecuta por separado.
    def analizar(self, entrada, codigo=0):
        datos = entrada.encode('utf-8') if isinstance(entrada, str) else entrada
        with tempfile.TemporaryDirectory(prefix='prueba-lexico-') as carpeta:
            archivo = Path(carpeta) / 'entrada.txt'
            archivo.write_bytes(datos)
            resultado = subprocess.run(
                [EJECUTABLE, str(archivo)], capture_output=True, timeout=15
            )
        salida = resultado.stdout.decode('utf-8')
        errores = resultado.stderr.decode('utf-8')
        self.assertEqual(resultado.returncode, codigo, errores)
        self.assertNotIn('Sanitizer', errores)
        self.assertNotIn('runtime error:', errores)
        self.assertIn('Errores lexicos: ' + str(errores.count('Linea ')), salida)
        tokens = [tuple(map(int, par)) for par in re.findall(r'^\((\d+),(-?\d+)\)$', salida, re.M)]
        return salida, errores, tokens

    # Se separan las filas de una tabla para revisar posiciones y datos exactos.
    def filas(self, salida, titulo):
        bloque = salida.split(titulo + '\n', 1)[1].split('\n\n', 1)[0]
        return bloque.splitlines()[1:]

    def test_catalogos_completos(self):
        catalogos = {
            0: 'bool cad cte def decisión elegir flot fls haz if int leer mientras mostrar para regresa vdd',
            2: ':= :+ :- :* :/ :%',
            3: '+q -q +iq -iq :i d/i',
            4: '&+ &- &* &/ &&* &%& &*&',
            5: '@> $$ #? ::= ?= %~ +',
        }
        entrada = ' '.join(catalogos.values())
        esperados = [(clase, indice) for clase, textos in catalogos.items()
                     for indice, _ in enumerate(textos.split())]
        salida, errores, tokens = self.analizar(entrada)
        self.assertEqual(tokens, esperados)
        self.assertEqual(errores, '')
        self.assertEqual(self.filas(salida, 'TABLA DE SIMBOLOS'), [])

    def test_orden_catalogo_no_depende_de_entrada(self):
        _, _, tokens = self.analizar('vdd bool int bool')
        self.assertEqual(tokens, [(0, 16), (0, 0), (0, 10), (0, 0)])

    def test_identificadores_repetidos_y_mayusculas(self):
        salida, _, tokens = self.analizar('I_a_I I_A_I I_a_I I_hola__I I_valor_mayor_I')
        self.assertEqual(tokens, [(1, 0), (1, 1), (1, 0), (1, 2), (1, 3)])
        self.assertEqual(self.filas(salida, 'TABLA DE SIMBOLOS'), [
            '0\tI_a_I\t-1', '1\tI_A_I\t-1', '2\tI_hola__I\t-1',
            '3\tI_valor_mayor_I\t-1'
        ])

    def test_limite_identificador_y_recuperacion(self):
        corto = 'I_' + 'a' * 28 + '_I'
        largo = 'I_' + 'a' * 29 + '_I'
        salida, errores, tokens = self.analizar(corto + '\n' + largo + ' int', 1)
        self.assertEqual(tokens, [(1, 0), (0, 10)])
        self.assertEqual(len(self.filas(salida, 'TABLA DE SIMBOLOS')), 1)
        self.assertIn('Linea 2:', errores)
        self.assertIn('mas de 32', errores)

    def test_identificador_vacio(self):
        _, errores, tokens = self.analizar('I__I int', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertIn('cuerpo vacio', errores)

    def test_enteros_y_limites_de_int(self):
        bits = ctypes.sizeof(ctypes.c_int) * 8
        minimo = -(2 ** (bits - 1))
        maximo = 2 ** (bits - 1) - 1
        _, _, tokens = self.analizar(f'0i p10i n205i p{maximo}i n{-minimo}i')
        self.assertEqual(tokens, [(6, 0), (6, 10), (6, -205), (6, maximo), (6, minimo)])

    def test_desbordamiento_entero(self):
        bits = ctypes.sizeof(ctypes.c_int) * 8
        limite = 2 ** (bits - 1)
        _, errores, tokens = self.analizar(f'p{limite}i n{limite + 1}i p' + '9' * 80 + 'i int', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertEqual(errores.count('fuera del rango'), 3)

    def test_enteros_mal_formados(self):
        _, errores, tokens = self.analizar('p0i n0i p01i n01i 25i 00i int', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertEqual(errores.count('entero invalido'), 6)

    def test_reales_guardados_como_texto(self):
        textos = ['1.1', '.24', '-2.2', '32e-3', '-4.4E2', '1.0', '1e10', '1e0', '1.0']
        salida, _, tokens = self.analizar(' '.join(textos))
        self.assertEqual(tokens, [(7, i) for i in range(len(textos))])
        self.assertEqual(self.filas(salida, 'LITERALES REALES'),
                         [f'{i}\t"{texto}"' for i, texto in enumerate(textos)])

    def test_fronteras_normales_de_flex(self):
        salida, errores, tokens = self.analizar('2.2.3 1.2e int +1.2', 1)
        self.assertEqual(tokens, [(7, 0), (7, 1), (7, 2), (0, 10), (5, 6), (7, 3)])
        self.assertEqual(self.filas(salida, 'LITERALES REALES'),
                         ['0\t"2.2"', '1\t".3"', '2\t"1.2"', '3\t"1.2"'])
        self.assertEqual(errores.count('Linea'), 1)
        self.assertIn('0x65', errores)

    def test_cadenas_vacias_marcadores_y_repetidas(self):
        textos = ['', 'hola mundo', '@n @f @d @t', '<', 'hola mundo', '// /* */', '  ']
        salida, _, tokens = self.analizar(' '.join('<' + texto + '>' for texto in textos))
        self.assertEqual(tokens, [(8, i) for i in range(len(textos))])
        self.assertEqual(self.filas(salida, 'LITERALES CADENA'),
                         [f'{i}\t"{texto}"' for i, texto in enumerate(textos)])

    def test_intervalo_ascii_completo_en_cadenas(self):
        texto = ''.join(chr(valor) for valor in range(32, 127) if valor != 62)
        salida, _, tokens = self.analizar('<' + texto + '>')
        self.assertEqual(tokens, [(8, 0)])
        self.assertEqual(self.filas(salida, 'LITERALES CADENA'), ['0\t"' + texto + '"'])

    def test_cadenas_con_caracteres_invalidos(self):
        for caracter in [b'\t', b'\r', b'\x00', b'\x1f', b'\x7f', b'\xff', 'ñ'.encode()]:
            with self.subTest(caracter=caracter):
                salida, errores, tokens = self.analizar(b'<a' + caracter + b'b> int', 1)
                self.assertEqual(tokens, [(0, 10)])
                self.assertEqual(self.filas(salida, 'LITERALES CADENA'), [])
                self.assertIn('intervalo ASCII', errores)

    def test_cadena_sin_cerrar_en_linea(self):
        _, errores, tokens = self.analizar('<sin cierre\nint\n?', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertIn('Linea 1: cadena sin cerrar', errores)
        self.assertIn('Linea 3:', errores)

    def test_cadena_sin_cerrar_al_final(self):
        _, errores, tokens = self.analizar('int <sin cierre', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertIn('cadena sin cerrar', errores)

    def test_comentarios_y_lineas(self):
        _, errores, tokens = self.analizar('// uno\n/* dos\n*** / int\nfin */\n? int // sin salto', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertEqual(errores.count('Linea'), 1)
        self.assertIn('Linea 5:', errores)

    def test_comentario_sin_cerrar(self):
        _, errores, tokens = self.analizar('int\n/* sin\ncerrar', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertIn('Linea 2: comentario sin cerrar', errores)

    def test_cierre_suelto(self):
        _, errores, tokens = self.analizar('*/ int', 1)
        self.assertEqual(tokens, [(0, 10)])
        self.assertIn('cierre de comentario sin apertura', errores)

    def test_tokens_adyacentes_y_prefijos(self):
        _, _, tokens = self.analizar('int I_x_I:=p10i$$&*&+iq::=<>+q&*')
        self.assertEqual(tokens, [(0, 10), (1, 0), (2, 0), (6, 10), (5, 1),
                                  (4, 6), (3, 2), (5, 3), (8, 0), (3, 0), (4, 2)])

    def test_identificador_adyacente_ambiguo(self):
        _, _, tokens = self.analizar('I_a_II_b_I')
        self.assertEqual(tokens, [(1, 0)])

    def test_recuperacion_errores_intercalados(self):
        _, errores, tokens = self.analizar('int ? p0i I_x_I\n<mal\t> p1i', 1)
        self.assertEqual(tokens, [(0, 10), (1, 0), (6, 1)])
        self.assertEqual(errores.count('Linea'), 3)

    def test_archivo_vacio_y_delimitadores(self):
        for entrada in ['', ' \t\r\n', '// nada', '/**/']:
            with self.subTest(entrada=entrada):
                salida, errores, tokens = self.analizar(entrada)
                self.assertEqual(tokens, [])
                self.assertEqual(errores, '')
                self.assertIn('Errores lexicos: 0', salida)

    def test_crecimiento_de_las_cuatro_colecciones(self):
        nombres = [f'I_variable_{i}_I' for i in range(200)]
        entrada = ' '.join(nombres + nombres + ['1.0', '<dato>'] * 200)
        salida, _, tokens = self.analizar(entrada)
        self.assertEqual(len(tokens), 800)
        self.assertEqual(tokens[:200], tokens[200:400])
        self.assertEqual(len(self.filas(salida, 'TABLA DE SIMBOLOS')), 200)
        self.assertEqual(len(self.filas(salida, 'LITERALES REALES')), 200)
        self.assertEqual(len(self.filas(salida, 'LITERALES CADENA')), 200)
        self.assertEqual(tokens[-2:], [(7, 199), (8, 199)])

    def test_lexemas_mayores_que_buffer_de_flex(self):
        texto = 'a' * 70000
        salida, _, tokens = self.analizar('<' + texto + '> I_' + texto + '_I int', 1)
        self.assertEqual(tokens, [(8, 0), (0, 10)])
        self.assertEqual(self.filas(salida, 'LITERALES CADENA'), ['0\t"' + texto + '"'])

    def test_argumentos_y_archivo_inexistente(self):
        with tempfile.TemporaryDirectory(prefix='prueba-lexico-') as carpeta:
            inexistente = str(Path(carpeta) / 'no_existe.txt')
            for argumentos in [[], [inexistente], ['uno', 'dos']]:
                with self.subTest(argumentos=argumentos):
                    resultado = subprocess.run([EJECUTABLE] + argumentos, capture_output=True, timeout=15)
                    self.assertEqual(resultado.returncode, 2)
                    self.assertNotEqual(resultado.stderr, b'')

    # Los resultados se escribieron a partir del enunciado, no de la salida del programa.
    def test_ejemplos_guardados(self):
        esperados = json.loads((EJEMPLOS / 'esperados.json').read_text(encoding='utf-8'))
        self.assertEqual(set(esperados), {archivo.name for archivo in EJEMPLOS.glob('*.txt')})
        for nombre, datos in esperados.items():
            with self.subTest(archivo=nombre):
                salida, errores, tokens = self.analizar(
                    (EJEMPLOS / nombre).read_bytes(), datos['codigo']
                )
                self.assertEqual(tokens, [tuple(par) for par in datos['tokens']])
                self.assertEqual(self.filas(salida, 'TABLA DE SIMBOLOS'),
                                 [f'{i}\t{texto}\t-1' for i, texto in enumerate(datos['simbolos'])])
                for titulo, campo in [('LITERALES REALES', 'reales'), ('LITERALES CADENA', 'cadenas')]:
                    self.assertEqual(self.filas(salida, titulo),
                                     [f'{i}\t"{texto}"' for i, texto in enumerate(datos[campo])])
                lineas = [int(numero) for numero in re.findall(r'^Linea (\d+):', errores, re.M)]
                self.assertEqual(lineas, datos['lineas_error'])

    def test_cada_clase_al_final_sin_salto(self):
        casos = [('decisión', (0, 4)), ('I_fin_I', (1, 0)), (':%', (2, 5)),
                 ('d/i', (3, 5)), ('&*&', (4, 6)), ('::=', (5, 3)),
                 ('n10i', (6, -10)), ('-1e-3', (7, 0)), ('<>', (8, 0))]
        for texto, token in casos:
            with self.subTest(texto=texto):
                _, errores, tokens = self.analizar(texto)
                self.assertEqual(tokens, [token])
                self.assertEqual(errores, '')

    def test_finales_incompletos(self):
        for texto in ['<', '/*', '/* *', '/* **', ':', '&', 'I_', 'p']:
            with self.subTest(texto=texto):
                _, errores, tokens = self.analizar(texto, 1)
                self.assertEqual(tokens, [])
                self.assertIn('Linea 1:', errores)

    def test_finales_de_linea_windows(self):
        _, errores, tokens = self.analizar(b'int\r\n/* a\r\nb */\r\n? bool\r\n', 1)
        self.assertEqual(tokens, [(0, 10), (0, 0)])
        self.assertEqual(errores.count('Linea'), 1)
        self.assertIn('Linea 4:', errores)

    def test_bytes_desconocidos_fuera_de_cadena(self):
        for valor in [0, 1, 31, 127, 128, 255]:
            with self.subTest(byte=valor):
                _, errores, tokens = self.analizar(bytes([valor]) + b' int', 1)
                self.assertEqual(tokens, [(0, 10)])
                self.assertEqual(errores.count('Linea'), 1)
                self.assertIn(f'0x{valor:02X}', errores)

    def test_enteros_pegados(self):
        numeros = [0, 1, -1, 10, -10, 101, -101, 1000000, -1000000]
        entrada = ''.join('0i' if n == 0 else ('p' if n > 0 else 'n') + str(abs(n)) + 'i'
                          for n in numeros)
        _, _, tokens = self.analizar(entrada)
        self.assertEqual(tokens, [(6, n) for n in numeros])

    def test_capacidades_justas(self):
        for cantidad in [15, 16, 17, 31, 32, 33, 63, 64, 65]:
            with self.subTest(cantidad=cantidad):
                nombres = [f'I_v{i}_I' for i in range(cantidad)]
                salida, _, tokens = self.analizar(' '.join(nombres))
                self.assertEqual(tokens, [(1, i) for i in range(cantidad)])
                self.assertEqual(self.filas(salida, 'TABLA DE SIMBOLOS'),
                                 [f'{i}\t{nombre}\t-1' for i, nombre in enumerate(nombres)])

    def test_comentario_largo_y_cierres(self):
        _, errores, tokens = self.analizar('/*' + '*' * 70000 + '/int/**//**/bool')
        self.assertEqual(tokens, [(0, 10), (0, 0)])
        self.assertEqual(errores, '')

    def test_archivo_con_espacios_en_nombre(self):
        with tempfile.TemporaryDirectory(prefix='prueba-lexico-') as carpeta:
            archivo = Path(carpeta) / 'entrada con espacios.txt'
            archivo.write_text('int', encoding='utf-8')
            resultado = subprocess.run([EJECUTABLE, str(archivo)], capture_output=True, timeout=15)
            self.assertEqual(resultado.returncode, 0)
            self.assertEqual(resultado.stderr, b'')
            self.assertIn(b'(0,10)', resultado.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)
