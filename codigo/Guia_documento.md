# Guía para escribir el documento descriptivo

Autores: Isaac Campos y Benyy Arriaga.

Estas son notas para preparar el documento. Hay que redactarlo con nuestras palabras, añadir resultados de las pruebas y completar las actividades y conclusiones de cada integrante. La estructura siguiente sigue lo que pide **DescripProgAnalizadorLex_27-1.pdf, página 3**.

## 1. Descripción del problema

Explicar qué se necesita reconocer en un archivo fuente y qué información debe producir el análisis. Todavía no describir funciones de C en esta parte. El analizador identifica componentes, descarta delimitadores y comentarios, guarda tablas y reporta errores con su línea. No ejecuta el programa de entrada ni comprueba su sintaxis.

Describir las nueve clases, sus restricciones y sus expresiones regulares. Los números de clase y valores de los catálogos son los del enunciado, páginas 1 y 2. Conviene incluir una tabla con clase, características, expresión y ejemplos válidos e inválidos. Copiar las expresiones de la versión definitiva de `analizador.l` al terminar, para que coincidan con la entrega.

| Clase | Regla del archivo | Qué explicar |
|---|---|---|
| 0, reservadas | `reservada` | Las 17 palabras exactas; se distinguen mayúsculas. `decisión` lleva tilde. |
| 1, identificadores | `identificador` | Prefijo `I_`, cuerpo de letras ASCII, dígitos o `_`, sufijo `_I`. Cuerpo no vacío y límite total de 32. |
| 2, asignación | `op_asignacion` | Los seis lexemas y sus valores fijos. El guion al inicio de la clase de caracteres es literal. |
| 3, relacionales | `op_relacional` | Las variantes con `+`, `-`, `i` opcional y `q`, además de `:i` y `d/i`. |
| 4, aritméticos | `op_aritmetico` | Las siete alternativas entre comillas para tratar los signos literalmente. |
| 5, especiales | `sim_especial` | Las siete alternativas del catálogo; `+` también puede aparecer por sí solo. |
| 6, enteros | `entero` | `0i` para cero; `p/n`, primer dígito no nulo y sufijo `i` para los demás. |
| 7, reales | `real` | Explicar también `digito`, `decimal` y `exponente`; menos opcional y dígitos después del punto. |
| 8, cadenas | `cadena` | Contenido ASCII 32 a 126, puede estar vacío; el primer `>` termina la cadena. |

### Detalles que no se deben perder

- **Longitud de identificadores:** el límite de 32 incluye los cuatro caracteres de `I_` y `_I`. Por eso el cuerpo puede tener de 1 a 28 caracteres con nuestra decisión de no permitirlo vacío. La expresión reconoce el nombre completo y después `yyleng` comprueba el límite. No se recorta un nombre largo ni se inserta en la tabla. Flex cuenta bytes; como todos los caracteres permitidos aquí son ASCII, coincide con el número de caracteres. El `\0` de almacenamiento en C no cuenta como parte del nombre.
- **Cadenas vacías:** la página 1 dice que pueden contener cero o más caracteres. Por eso `<>` es válido; cambiar `*` por `+` incumpliría esa definición.
- **Cierre de cadenas:** `>` es el delimitador aunque su código esté en el intervalo permitido. El contenido usa ASCII 32..61 y 63..126. `<` sí puede aparecer dentro: `<<>` guarda `<`. No hay un mecanismo de escape para guardar `>` dentro del contenido.
- **Marcadores:** `@n`, `@f`, `@d` y `@t` se conservan como texto; el analizador no sustituye valores.
- **Otros tamaños:** el enunciado no fija una longitud máxima para cadenas o reales, ni un máximo de entradas en las tablas. Se usa memoria dinámica. Los enteros deben caber en el campo `int` de nuestro token; es un límite de implementación, no una restricción numérica escrita en el PDF.

## 2. Propuesta de solución y fases del desarrollo

### Análisis y planificación

Indicar quién participó en cada actividad, como exige el enunciado. Completar esta parte con lo que realmente hizo cada integrante; no asignar tareas ni fechas por suposición.

| Actividad | Participante(s) y trabajo realizado |
|---|---|
| Leer los requisitos y resolver ambigüedades | Por completar |
| Definir y revisar expresiones regulares | Por completar |
| Diseñar tokens y tablas | Por completar |
| Implementar reglas y funciones en C | Por completar |
| Preparar pruebas y revisar resultados | Por completar |
| Redactar y revisar el documento | Por completar |

Fuentes: el enunciado define el lenguaje y la entrega; `Tema-2-Analisis-Lexico.pdf` explica el análisis léxico y sus decisiones de reconocimiento; `DescripcionUsoLEX.pdf` explica la estructura del archivo Lex/Flex, expresiones, acciones y compilación con `-lfl`.

### Diseño: recorrido del programa

Explicar las tres secciones separadas por `%%`: definiciones, reglas y funciones en C. Dentro del mismo `.l` se mantienen funciones separadas para buscar, insertar, convertir, mostrar y liberar memoria. No se necesita `tablas.c` ni Bison para esta tarea.

Recorrido para describir: `main` recibe la ruta, abre `yyin`, llama a `yylex`, las acciones llenan las tablas y finalmente se muestran resultados. Flex elige el lexema más largo y, cuando hay empate, la primera regla. Las reglas válidas se colocan antes de reglas de error que también podrían reconocer ese mismo texto.

### Diseño: estructuras, búsqueda e inserción

La página 3 pide explicar estos puntos, no poner solamente las declaraciones de C.

| Estructura | Campos y uso |
|---|---|
| `Token` | `clase` identifica una de las nueve clases; `valor` es el índice correspondiente o el valor numérico para enteros. Ambos son `int`. Se almacenan en orden de aparición. |
| `Simbolo` | `posicion`, `nombre` completo y `tipo`, inicialmente `-1`. Se guarda una sola entrada por identificador distinto. |
| `Literal` | `posicion` y `dato` como texto. Se usa en dos tablas independientes, una para reales y otra para cadenas. Cada aparición crea una entrada, incluso si se repite. |
| `TablaLiterales` | Apuntador al arreglo de literales, cantidad utilizada y capacidad reservada. Estos campos administran el arreglo; cada literal sigue teniendo sólo posición y dato. |
| Catálogos | Arreglos fijos de texto. El orden reproduce los valores de la página 2. No se modifican durante el análisis. |

La búsqueda de símbolos recorre las entradas con `strcmp`. Si encuentra el nombre devuelve su posición; si no, lo copia al final con tipo `-1`. Es búsqueda lineal: sencilla para esta tarea, aunque puede revisar toda la tabla. Los catálogos también se buscan linealmente. En literales no se busca antes de insertar, por instrucción expresa del PDF.

Ejemplo para explicar: `int I_x_I := n25i I_x_I` produce `(0,10) (1,0) (2,0) (6,-25) (1,0)`. Los dos usos del identificador apuntan a la misma entrada. Con `1.0 1.0`, en cambio, se crean dos posiciones en reales.

Los reales se guardan con su escritura original, sin convertir a `float`. Las cadenas se guardan sin sus delimitadores. Sus posiciones empiezan en cero.

### Diseño: memoria y detalles de C

- `CAPACIDAD_INICIAL` vale 16 por elección de implementación, no por requisito. Es la primera reserva, no el máximo de elementos. Cuando un arreglo se llena, su capacidad se duplica.
- `CANTIDAD(arreglo)` calcula cuántas entradas tiene un catálogo usando `sizeof`. Sólo se aplica al arreglo completo; un parámetro apuntador no conserva esa información.
- `asegurarEspacio` recibe la dirección de la capacidad para actualizarla y devuelve el apuntador al arreglo. Usa `void *` para servir a varias estructuras y `size_t` para tamaños en bytes.
- Se comprueba que duplicar la capacidad y multiplicar por el tamaño de entrada no desborde. `(size_t)-1` expresa el máximo de ese tipo sin signo en C90. El apuntador temporal de `realloc` conserva el bloque anterior si la reserva falla.
- `copiarTexto` reserva una copia y agrega `\0`. Es necesario porque Flex reutiliza `yytext`. Primero se liberan los textos de las entradas y después los arreglos.
- `static` mantiene las variables y funciones auxiliares dentro del archivo. `const` impide modificar los catálogos a través de sus declaraciones.
- `strtol` permite revisar la conversión de enteros: se reinicia `errno`, se revisa `ERANGE`, el final de la conversión y los límites de `int`. El signo `p/n` se transforma temporalmente en `+/-` y se quita la `i`.
- Los errores por byte usan `unsigned char` para evitar valores negativos y luego `unsigned int`, que corresponde a `%X`. El contador de errores es `unsigned long` y se imprime con `%lu`.
- `atexit` registra `liberarRecursos`; se ejecuta al regresar de `main` o llamar a `exit`. Cierra la entrada, libera el búfer de Flex y nuestras tablas.

Las bibliotecas usadas son estándar de C: `errno.h` para errores de conversión, `limits.h` para límites de enteros, `stdio.h` para archivos y salida, `stdlib.h` para memoria/conversión/terminación y `string.h` para operaciones con texto.

### Diseño: opciones de Flex y comentarios

**Estas opciones y el estado exclusivo no se explican en `DescripcionUsoLEX.pdf`.** Su apartado de comentarios habla de cómo comentar el propio archivo `.l`; no da esta implementación para descartar comentarios del archivo de entrada. El enunciado, página 3, sí exige descartar comentarios `//` y `/* ... */`. El Tema 2 también señala esa tarea del analizador, pero no prescribe estas reglas de Flex.

| Recurso | Para qué se usa y alternativa |
|---|---|
| `yylineno` | Mantiene el número de línea. Podría sustituirse por un contador propio actualizado en todas las reglas que consumen saltos. |
| `noinput`, `nounput` | Evitan generar dos funciones que no utilizamos. No son requisitos del lenguaje reconocido. |
| `never-interactive` | Como la entrada es un archivo, evita consultar si se trata de una terminal. |
| `nounistd` | Evita incluir `unistd.h`, que pertenece a POSIX. Junto con la opción anterior permite esta compilación sin depender de esas interfaces. |
| `nodefault` | Desactiva el eco automático de caracteres sin regla. Las reglas explícitas cubren la entrada y reportan bytes desconocidos. |
| `%x COMENTARIO` | Permite activar sólo las reglas del comentario de bloque. `BEGIN(COMENTARIO)` entra y `BEGIN(INITIAL)` vuelve al reconocimiento normal. |
| `-lfl` | Enlaza la biblioteca que proporciona `yywrap`. El ejemplo del PDF también usa esta bandera. No se usa `noyywrap`. |

Ninguna de estas opciones es una regla obligatoria del lenguaje de la tarea. Se conservan para contar líneas, controlar el código generado y separar el manejo de comentarios. Son instrucciones de Flex, no extensiones del lenguaje C.

Para `//`, una expresión descarta hasta antes de `\n`. Para bloques, se guarda la línea de apertura y se descarta el contenido hasta el primer cierre. Los saltos siguen actualizando `yylineno`. Si termina el archivo dentro de `COMENTARIO`, se informa el error en la línea donde empezó el bloque. No se admiten comentarios anidados. Un marcador de comentario dentro de una cadena válida se guarda como parte de su texto.

**Alternativa sin estado:** se podría usar una expresión para un bloque completo y otra para detectar que falta el cierre, cuidando no consumir más allá del primer `*/`. También se podría leer carácter por carácter desde una acción, manteniendo el conteo de líneas y el final de archivo. Se eligió el estado porque deja separados apertura, contenido, cierre y error al final. No es indispensable, pero evita juntar esos casos en una expresión difícil de leer.

Referencia complementaria: el [manual de Flex sobre estados](https://westes.github.io/flex/manual/Start-Conditions.html) explica `%x`, `BEGIN` y muestra un ejemplo para descartar comentarios. No atribuir ese ejemplo a los PDF de clase.

### Diseño: decisiones y recuperación de errores

Separar en la redacción los requisitos del PDF de las decisiones acordadas:

- Cuerpo de identificador no vacío: decisión acordada; el PDF no da un mínimo explícito.
- Enteros no nulos con `p/n` y sin ceros iniciales: criterio acordado; cero solamente como `0i` sí es explícito en el enunciado.
- Reales: menos opcional, sin `+` dentro del exponente, con dígitos después del punto. Son precisiones acordadas a partir de los ejemplos. `1.` y `1e+2` no son reales completos válidos.
- Reconocimiento normal de Flex: `2.2.3` son los reales `2.2` y `.3`; `1.2e` da un real y un error por `e`. El Tema 2 presenta distintas posibilidades para números mal formados; elegimos continuar con los lexemas reconocibles. `+1.2` produce el símbolo `+` seguido del real `1.2`.
- Delimitadores: espacio, tabulador y `\n`. Se retiró `\r` por trabajar con archivos de Linux. Fuera de comentarios se reporta como byte desconocido; dentro de una cadena es contenido inválido.
- Ante un identificador demasiado largo, entero inválido o fuera de rango, no se agrega el token. Una cadena inválida se descarta hasta su cierre o antes del salto de línea. Un byte desconocido se consume y se continúa. Un bloque sin cierre consume hasta el final, por lo que ya no hay entrada posterior que recuperar.
- Los errores van a `stderr`; las tablas, tokens y total de errores a `stdout`. El PDF exige mostrar resultados y permite guardarlos en archivos de manera opcional. La redirección de la terminal permite conservarlos sin añadir funciones de escritura al programa.

### Pruebas

Explicar entrada, resultado esperado y resultado obtenido. Incluir ejemplos representativos y la ejecución de las pruebas, no pegar todas las salidas enormes.

Revisar los 11 archivos descritos en `ejemplos/README.md` y las 34 pruebas de `probar.py`. Cubren catálogos completos, repetición de identificadores y literales, longitudes de 32 y 33 caracteres, enteros límite y desbordamientos, reales, cadenas vacías y ASCII, comentarios, líneas de error y recuperación. También hay pruebas de crecimiento de tablas, textos largos, bytes inválidos, entrada vacía y problemas al abrir archivos.

Registrar la versión de Flex/GCC, sistema utilizado, comando ejecutado y resultado real. El programa se prueba aquí en Fedora; no afirmar que ya se ejecutó en Ubuntu. Python sólo se necesita para ejecutar las pruebas automáticas.

## 3. Indicaciones para correr el programa

Desde la carpeta del `.l`, incluir estos comandos individuales y explicar qué produce cada uno:

```sh
flex analizador.l
gcc -std=c90 -Wall -Wextra -pedantic-errors lex.yy.c -o analizador -lfl
./analizador ejemplo.txt
python3 probar.py ./analizador
```

Flex genera `lex.yy.c`; GCC lo compila y enlaza con la biblioteca de Flex; el ejecutable recibe la ruta del archivo a analizar. La última instrucción es para las pruebas de trabajo, cuyos archivos no forman parte del ZIP indicado para la entrega. No se utiliza Make.

Explicar requisitos (Flex, compilador C y biblioteca de Flex), entrada por argumento y estados de salida: 0 sin errores léxicos, 1 con errores léxicos y 2 por un fallo que impide completar la ejecución. Para conservar resultados:

```sh
./analizador ejemplo.txt > resultados.txt 2> errores.txt
```

Indicar que las redirecciones reemplazan esos archivos si ya existen. Al documentar una ejecución que la profesora pueda repetir usando sólo el ZIP, incluir el contenido de una entrada pequeña y explicar cómo guardarla en `ejemplo.txt`.

## 4. Conclusiones por participante

Isaac y Benyy deben escribir sus conclusiones por separado. Comentar qué entendió cada quien sobre expresiones, prioridad de reglas, tablas, errores o memoria en C; qué dificultad tuvo y cómo la resolvió. Completar con experiencias reales, no con conclusiones asignadas de antemano.

## Antes de preparar la entrega

Verificar que las expresiones y decisiones descritas coincidan con el `.l` final. La cabecera del programa tiene autores y fecha; cada función tiene una explicación breve y se mantiene la sangría solicitada. Revisar nombres, fecha y conclusiones con ambos participantes.

El ZIP debe contener `analizador.l` y el documento descriptivo terminado. Esta guía, los PDF de referencia, las pruebas, el ejecutable y `lex.yy.c` son materiales de trabajo y no sustituyen el documento solicitado.
