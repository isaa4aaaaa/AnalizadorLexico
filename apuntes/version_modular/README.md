# Analizador léxico

> Copia histórica de la versión con varios archivos. La versión actual está en `../../codigo/analizador.l` y sus instrucciones están en `../../codigo/README.md`. Estos archivos se conservan como respaldo y no se incluyen en la entrega.

Autores: Isaac Campos y Benyy Arriaga. Fecha: 29 de septiembre de 2026.

Reconoce las nueve clases de `DescripProgAnalizadorLex_27-1.pdf`. Recibe un archivo, muestra la tabla de símbolos, las dos tablas de literales y la secuencia de tokens. Los errores se informan con su línea y el análisis continúa.

## Compilación y ejecución

Requiere Flex y un compilador de ANSI C. Bison no se utiliza en esta etapa.

```sh
make
./analizador pruebas/ejemplo.txt
```

Los comandos equivalentes, sin Make, son:

```sh
flex -o lex.yy.c analizador.l
gcc -std=c90 -Wall -Wextra -pedantic-errors -O2 lex.yy.c tablas.c -o analizador
./analizador archivo_fuente.txt
```

Se utiliza C90: declaraciones al inicio de los bloques, comentarios de C y funciones de la biblioteca estándar. No se usa `strdup`, `getline`, arreglos de longitud variable ni extensiones de C99. Las opciones `never-interactive` y `nounistd` evitan que el escáner dependa de las funciones POSIX de terminales o de `unistd.h`. `noyywrap` permite compilar sin enlazar `-lfl`.

Para guardar resultados y errores por separado:

```sh
./analizador archivo_fuente.txt > resultados.txt 2> errores.txt
```

El estado de salida es 0 si no hubo errores, 1 si hubo errores léxicos y 2 si no fue posible ejecutar o completar el análisis por un problema de argumentos, archivo, memoria o salida.

## Organización

| Archivo | Responsabilidad |
|---|---|
| `analizador.l` | Patrones, acciones, catálogos, comentarios, errores y función principal |
| `tablas.h` | Clases de tokens, estructuras y declaraciones de funciones |
| `tablas.c` | Almacenamiento, búsqueda, impresión y liberación de memoria |
| `Makefile` | Generación con Flex y compilación en C90 |
| `pruebas/ejemplo.txt` | Entrada pequeña para ejecutar manualmente |
| `pruebas/probar.py` | Pruebas automáticas; requiere Python 3 sólo para probar |
| `apuntes/analizador_guiado.l.txt` | Copia del cuaderno anterior, incluidas tus respuestas y avances |

`lex.yy.c` y `analizador` se generan al compilar. No edites el C generado: modifica `analizador.l` y vuelve a ejecutar `make`. `fiunamfs` se consultó como referencia de estilo y no forma parte de este analizador.

## Datos y funciones

El token contiene dos enteros: clase y valor. El valor es una posición de catálogo o tabla, excepto para constantes enteras, donde es el número representado.

La tabla de símbolos es un arreglo dinámico de registros con posición, nombre y tipo. `buscarOInsertarSimbolo` recorre los nombres con `strcmp`: devuelve una posición existente o inserta un registro nuevo con tipo -1. La búsqueda es lineal; no cambia los tipos ni realiza análisis semántico.

Cada tabla de literales tiene registros con posición y dato textual. Los reales conservan el lexema completo; las cadenas conservan sólo el contenido entre `<` y `>`. `insertarLiteral` guarda una nueva copia en cada aparición, sin buscar duplicados. Reales y cadenas tienen contadores independientes.

Los arreglos empiezan vacíos y reservan 16 elementos al necesitar el primero. Duplican su capacidad cuando se llenan. Se distingue entre cantidad utilizada y capacidad, se comprueba el tamaño de la reserva y se conserva el apuntador original si `realloc` falla. El tamaño de los índices está limitado por `int` y la memoria disponible.

`liberarRecursos`, registrada con `atexit`, cierra el archivo y libera tanto el escáner como las tablas, también si una reserva falla y termina con `exit`. Los nombres y los datos se copian antes de que Flex reutilice `yytext`.

## Interpretaciones confirmadas

- Los identificadores tienen de 1 a 28 caracteres en el cuerpo, además de `I_` y `_I`. Se aceptan letras ASCII, dígitos y `_`; se distinguen mayúsculas y minúsculas. La longitud total máxima es 32.
- Los enteros no nulos requieren `p` o `n`, no aceptan ceros iniciales y terminan en `i`. El cero se escribe sólo `0i`. Su valor debe caber en `int`; un desbordamiento es un error recuperable.
- Los reales admiten menos opcional. La forma decimal requiere al menos un dígito después del punto; la forma científica acepta `e` o `E`, menos opcional en el exponente y uno o más dígitos. `1.`, `+1.2` y `1e+2` no son lexemas reales completos de esta definición.
- En cadenas se admite `<` interno y el primer `>` cierra la cadena. `<>` es válida; los saltos de línea, tabuladores y caracteres fuera de ASCII 32..126 no lo son. Los marcadores `@n`, `@f`, `@d` y `@t` se conservan como texto; esta etapa no los sustituye.
- La reservada de valor 4 es `decisión`, con tilde, como aparece en el catálogo. Los archivos con esa palabra deben usar UTF-8. La restricción ASCII de las cadenas no se aplica al catálogo de reservadas.
- Los comentarios de bloque no se anidan. Los marcadores de comentario dentro de una cadena válida son parte de su contenido.

El enunciado del proyecto prevalece sobre los ejemplos generales de Tema 2: aquí las clases conservan sus números y los literales repetidos siempre se insertan. No se añade un analizador sintáctico, ejecución de instrucciones ni comprobación de tipos.

## Errores y fronteras entre componentes

Un identificador demasiado largo se consume completo y no se inserta. Una forma entera como `p0i`, `n01i` o `25i` se reporta completa. Para una cadena inválida se consume hasta el cierre; si falta, hasta antes del salto de línea o hasta EOF. Un comentario de bloque sin cierre informa la línea de apertura al alcanzar EOF. Los demás caracteres desconocidos se consumen de uno en uno y se indican por su byte para hacer visibles también caracteres de control.

Flex prefiere la coincidencia más larga; sólo en empate gana la regla anterior. Por eso `&*&` se reconoce como raíz y no como multiplicación seguida de otro carácter. Se permiten componentes adyacentes, como `I_x_I:=p1i`.

Se confirmó usar este reconocimiento normal también en números: `2.2.3` produce dos reales (`2.2` y `.3`), y `1.2e` produce el real `1.2` seguido de un error por `e`. No se agrupan esos fragmentos en un único error numérico.

Si toda una concatenación es un identificador válido, como `I_a_II_b_I`, se reconoce como uno solo. Para expresar dos identificadores en ese caso debes separarlos. Igualmente, el símbolo `+` seguido del real `1.2` puede formar dos tokens válidos, aunque `+1.2` no sea un único real.

## Pruebas

```sh
make probar
```

Las 25 pruebas comprueban los catálogos completos, valores fijos, identificadores repetidos y de longitud límite, enteros y sus límites de rango, reales y cadenas repetidos, caracteres ASCII, comentarios, líneas de error, tokens adyacentes, recuperación y argumentos. También verifican crecimiento de las cuatro colecciones, lexemas mayores que el buffer inicial de Flex y el reconocimiento normal de fronteras numéricas que se confirmó para esta entrega.

No se pudieron ejecutar AddressSanitizer y UndefinedBehaviorSanitizer en este entorno porque faltan las bibliotecas `libasan` y `libubsan`. Esto no afecta a la compilación normal; las pruebas funcionales se ejecutan con el programa compilado en C90.

## Referencias de implementación

- `DescripProgAnalizadorLex_27-1.pdf`: clases, valores, tablas, recuperación y entrega.
- `Tema-2-Analisis-Lexico.pdf`, pp. 1–3, 5–7 y 9–11: ciclo del analizador, tablas, fronteras y tokens.
- `DescripcionUsoLEX.pdf`, sección 2.6: estructura del archivo Flex, expresiones y acciones.
- [Manual oficial de Flex: coincidencias](https://westes.github.io/flex/manual/Matching.html): longitud y desempate por orden.
- [Manual oficial de Flex: memoria de yytext](https://westes.github.io/flex/manual/A-Note-About-yytext-And-Memory.html): necesidad de conservar copias propias.
- [Manual oficial de Flex: estados](https://westes.github.io/flex/manual/Start-Conditions.html): modo exclusivo para comentarios.
- [SEI CERT C: funciones con comprobación de errores](https://cmu-sei.github.io/secure-coding-standards/sei-cert-c-coding-standard/recommendations/error-handling-err/err07-c/): conversión comprobable con `strtol` en vez de `atoi`.
- [SEI CERT C: tamaño de las reservas](https://cmu-sei.github.io/secure-coding-standards/sei-cert-c-coding-standard/rules/memory-management-mem/mem35-c/): comprobar tamaños antes de reservar.

Para preparar la entrega del código, incluye `analizador.l`, `tablas.c` y `tablas.h`; puedes acompañarlos del `Makefile` y el ejemplo. El documento académico que pide el enunciado también debe entregarse y necesita la planificación y las conclusiones de cada participante; este README explica el programa y no reemplaza esas secciones.
