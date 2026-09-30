# Ejemplos para revisar el analizador

Estos archivos prueban el reconocimiento léxico. No necesitan formar programas con una gramática correcta.

Desde `codigo/`, ejecuta cualquier archivo así:

```sh
./analizador ejemplos/03_limites_identificadores.txt
```

Los casos con errores deben terminar con estado 1 y seguir mostrando las tablas y los tokens válidos. Los demás terminan con 0. Puedes consultar el estado con `echo $?` inmediatamente después de ejecutar el programa.

## Qué debe pasar en cada archivo

| Archivo | Qué comprueba | Tokens | Errores |
|---|---|---:|---:|
| `01_catalogos.txt` | Todas las reservadas, operadores y símbolos, en orden de catálogo | 43 | 0 |
| `02_repeticiones.txt` | Identificador repetido, mayúsculas, reales y cadenas repetidos | 12 | 0 |
| `03_limites_identificadores.txt` | Cuerpos con `_` y dígitos, longitud total 32 y 33, cuerpo vacío | 6 | 2 |
| `04_limites_enteros.txt` | Límites de int de 32 bits, desbordamientos, ceros y signos inválidos | 9 | 7 |
| `05_reales_y_fronteras.txt` | Ceros decimales, exponentes grandes y componentes pegados | 14 | 1 |
| `06_cadenas.txt` | Cadena vacía, espacios, `<` interno, marcadores, tabulador y acento | 10 | 4 |
| `07_comentarios.txt` | Comentarios entre tokens, cierre suelto y bloque sin cerrar | 7 | 2 |
| `08_sin_espacios.txt` | Operadores con prefijos parecidos y tokens adyacentes | 25 | 0 |
| `09_recuperacion.txt` | Errores intercalados con tokens válidos | 7 | 5 |
| `10_crecimiento.txt` | 40 símbolos, 40 reales y 40 cadenas; crece la memoria reservada | 202 | 0 |
| `11_solo_comentarios.txt` | Archivo sin componentes que generen tokens | 0 | 0 |

Los resultados completos están en `esperados.json`: tokens, nombres, reales, cadenas y líneas de error. Se prepararon a partir de los requisitos y se comparan con la salida del programa. No necesitas editar ese archivo para ejecutar los ejemplos.

## Detalles que conviene comprobar

**Repeticiones.** En `02`, la tabla de símbolos debe tener sólo `I_x_I` e `I_X_I`. Los dos reales `1.0` ocupan posiciones diferentes. Las cadenas son `hola`, `hola` y la vacía, también en tres posiciones.

**Identificadores.** En `03`, `I_abcdefghijklmnopqrstuvwxyz12_I` mide 32 caracteres y se acepta. Al agregarle un dígito mide 33 y se informa el error de la línea 5. El identificador vacío falla en la línea 6. Los tokens finales deben ser `(0,10)` y `(1,0)`, reutilizando el primer nombre.

**Enteros.** En `04`, se aceptan `p2147483647i` y `n2147483648i`. Se informan tres desbordamientos en la línea 2 y cuatro formas inválidas en la línea 3. La última línea sigue generando sus cuatro tokens. Estos límites corresponden al `int` de 32 bits de este equipo Fedora; el programa usa `INT_MIN` e `INT_MAX` del compilador.

**Reales.** En `05`, `1e1000000` es válido: el real se guarda como texto y no se convierte a un tipo de punto flotante. `2.2.3` produce dos reales. `+1.2` produce el símbolo `+` y el real `1.2`. En la línea 3, `1.2e` produce un real y un error por la letra `e`; todavía se reconoce `int`.

**Cadenas.** En `06`, hay un tabulador real dentro de la cadena de la línea 5; algunos editores lo muestran como espacios. La `ñ` de la línea 6 está fuera del intervalo ASCII permitido. Las líneas con error son 3, 5, 6 y 7. En la última, `<>` sí genera token y el `>` sobrante se reporta como error. Las comillas y la barra invertida de la línea 2 se conservan como texto, sin interpretar escapes.

**Comentarios.** En `07`, se reporta el cierre suelto de la línea 5 y la apertura sin cierre de la línea 6. El texto de la línea 7 pertenece a ese comentario y no genera tokens. El texto entre `<` y `>` de la línea 4 sí es una cadena, aunque contenga dos barras.

**Tokens pegados.** En `08`, `&*&` debe generar sólo `(4,6)`. El último texto, `I_a_II_b_I`, es un solo identificador válido por la coincidencia más larga de Flex.

**Recuperación.** En `09`, los errores están en las líneas 1, 2, 3, 5 y 6. La secuencia completa debe ser:

```text
(0,10) (1,0) (2,0) (5,1) (6,5) (0,13) (0,0)
```

**Crecimiento.** En `10`, cada tabla tiene 40 entradas. Los últimos dos tokens son `(1,0)` y `(1,39)`, porque esos nombres ya se habían insertado. No deben aparecer símbolos repetidos.

## Comprobación automática

Desde `codigo/`:

```sh
python3 probar.py ./analizador
```

Además de estos archivos, las pruebas crean entradas temporales con bytes nulos y otros caracteres no imprimibles, un `\r` que debe reportarse como error fuera de comentarios, tokens al final sin salto de línea, aperturas sin cierre y textos de 70 000 caracteres. También revisan las capacidades 15, 16, 17, 31, 32, 33, 63, 64 y 65 para detectar problemas al ampliar arreglos.

Que las pruebas pasen comprueba estos casos concretos; no demuestra que toda entrada posible esté libre de fallos. Los ejemplos y las pruebas son material de revisión y no se agregan al ZIP de entrega.
