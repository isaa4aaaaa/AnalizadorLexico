# Analizador léxico

**Autores:** Isaac Campos y Benyy Arriaga.

Todo el programa está en **`analizador.l`**. Está escrito con Flex y ANSI C (C90).

En esta carpeta también están `ejemplo.txt`, una entrada para probarlo, y `probar.py`, las pruebas automáticas opcionales. En [ejemplos/README.md](ejemplos/README.md) se explican otros 11 archivos con casos válidos, errores y límites. Para la entrega que indicas, el ZIP debe contener únicamente **`analizador.l` y tu documento descriptivo**. Este README sirve para revisar el código; no sustituye el documento académico. La versión anterior está guardada fuera de esta carpeta, en `apuntes/version_modular/`.

## Cómo está organizado el archivo

Flex divide el archivo con dos líneas `%%`:

1. **Definiciones:** bibliotecas, estructuras, tablas, catálogos y expresiones regulares. Los números de los catálogos coinciden con el enunciado.
2. **Reglas:** cada expresión tiene una acción. Al reconocer un componente, la acción busca o guarda su valor y agrega un token. Espacios y comentarios se descartan.
3. **Funciones en C:** búsqueda, almacenamiento, conversión de enteros, impresión, liberación de memoria y `main`.

Las funciones siguen separadas por responsabilidad, aunque ahora están dentro del mismo archivo.

En [Guia_documento.md](Guia_documento.md) quedan los puntos para redactar el documento de entrega: requisitos del PDF, decisiones de diseño, uso de Flex y pruebas que conviene explicar.

## Datos y funciones que conviene revisar

| Parte | Qué hace |
|---|---|
| `Token` y `agregarToken` | Guardan clase y valor, ambos enteros, en orden de aparición. |
| `Simbolo` y `buscarOInsertarSimbolo` | Buscan el nombre con `strcmp`. Si ya existe, reutilizan su posición; si no, guardan posición, nombre y tipo -1. |
| `Literal`, `insertarReal` e `insertarCadena` | Guardan cada aparición en su tabla, incluso si se repite. El real queda como texto; la cadena, sin `<` y `>`. |
| `buscarCatalogo` y `registrarCatalogo` | Obtienen el valor fijo de una reservada, operador o símbolo. |
| `registrarEntero` | Traduce `p/n` al signo y usa `strtol` para convertir y revisar que el número quepa en `int`. |
| `asegurarEspacio` y `copiarTexto` | Amplían los arreglos y conservan copias del texto que Flex reconoce. |
| `informarError` | Informa la línea y permite continuar. El estado `COMENTARIO` también detecta bloques sin cerrar. |
| `mostrarResultados` | Imprime símbolos, reales, cadenas y tokens. |
| `liberarTablas` y `liberarRecursos` | Liberan las copias, arreglos, archivo y memoria de Flex al terminar. |
| `main` | Revisa el argumento, abre el archivo, llama a `yylex` y muestra resultados. Registra la limpieza con `atexit`. |

Las búsquedas son lineales: recorren las entradas una por una. Cada arreglo lleva cantidad utilizada y capacidad disponible; reserva 16 posiciones inicialmente y crece cuando se llena. `realloc` usa un apuntador temporal para conservar el bloque original si falla.

Por ejemplo, `int I_x_I := n25i I_x_I` genera `(0,10) (1,0) (2,0) (6,-25) (1,0)`. El identificador repetido conserva su posición y el entero guarda directamente su valor.

## Comportamiento acordado

- Identificadores con cuerpo no vacío y máximo 32 caracteres totales; `_` sí se permite dentro.
- Enteros con `p/n`, sin ceros iniciales; el cero sólo es `0i`.
- Reales con menos opcional; un decimal exige dígitos después del punto. No se reconoce `1.` ni `1e+2` como un solo real válido.
- Cadenas vacías permitidas; `<` puede estar dentro y el primer `>` cierra. Sólo ASCII 32..126. Los marcadores `@n`, `@f`, `@d` y `@t` se conservan como texto.
- Se distinguen mayúsculas; la reservada `decisión` lleva tilde y se escribe en UTF-8.
- Flex toma la coincidencia más larga: `2.2.3` produce dos reales; `1.2e` produce un real y un error en `e`. Los comentarios no se anidan.

El programa informa errores y sigue buscando componentes. No ejecuta instrucciones ni revisa la gramática del programa de entrada. Los estados de salida son **0** sin errores, **1** con errores léxicos y **2** ante un fallo de uso, archivo, memoria o salida.

## Cómo compilar, ejecutar y probar

En Fedora, `-lfl` necesita el paquete [libfl-devel](https://packages.fedoraproject.org/pkgs/flex/libfl-devel/fedora-44.html), además de Flex y GCC. Si al compilar aparece `cannot find -lfl`, instala esa dependencia una sola vez desde tu terminal:

```sh
sudo dnf install libfl-devel
```

Abre una terminal en la carpeta principal del proyecto y entra aquí:

```sh
cd codigo
```

**1. Generar el C con Flex:**

```sh
flex analizador.l
```

Lee tus reglas y crea `lex.yy.c`. Es un archivo generado: no lo edites ni lo incluyas en la entrega.

**2. Compilar ese C:**

```sh
gcc -std=c90 -Wall -Wextra -pedantic-errors lex.yy.c -o analizador -lfl
```

`gcc` crea el ejecutable. `-std=c90` selecciona ANSI C; `-Wall -Wextra` activan advertencias; `-pedantic-errors` rechaza extensiones que no cumplen ese estándar. `-o analizador` da nombre al ejecutable. `-lfl` enlaza la biblioteca de Flex, que proporciona `yywrap` para terminar al llegar al final del archivo, como en el ejemplo de clase. El programa define su propio `main`.

**3. Ejecutar el ejemplo:**

```sh
./analizador ejemplo.txt
```

`./` indica que el ejecutable está en la carpeta actual. `ejemplo.txt` es el archivo que se analizará; puedes cambiarlo por la ruta de otro archivo. Verás las tablas y los tokens. Después de modificar el `.l`, repite los pasos 1 y 2 antes de ejecutar.

**4. Pruebas automáticas opcionales:**

```sh
python3 probar.py ./analizador
```

Ejecuta 34 pruebas, algunas con varios subcasos, y debe terminar en `OK`. Una de ellas recorre los 11 archivos de `ejemplos/` y compara todos sus tokens, tablas y líneas de error con `esperados.json`. También se prueban bytes nulos, archivos sin salto final, rechazo de `\r` como delimitador, límites de capacidad y textos de 70 000 caracteres. Se usan saltos de línea `\n`, como en Linux. Python sólo se usa para las pruebas, no para compilar ni ejecutar el analizador.

Para revisar un caso manualmente, por ejemplo la recuperación después de errores:

```sh
./analizador ejemplos/09_recuperacion.txt
```

Ese archivo contiene errores a propósito. Debe mostrar cinco errores y conservar siete tokens válidos, como se detalla en la guía de ejemplos.

**Guardar la salida, si lo necesitas:**

La página 3 del enunciado exige mostrar las tablas y la secuencia de tokens, y añade: «También podrán almacenarse en archivos para su mejor revisión». Guardarlas en archivos es opcional; el programa cumple mostrándolas en pantalla. Con el siguiente comando puedes guardar toda la salida sin cambiar el código:

```sh
./analizador ejemplo.txt > resultados.txt 2> errores.txt
```

`>` guarda tablas y tokens; `2>` guarda los errores. Estos comandos reemplazan el contenido anterior de esos dos archivos.

**Preparar el ZIP cuando tengas el documento terminado:**

Coloca tu documento en esta carpeta. Si se llama `documento_descriptivo.pdf`, ejecuta:

```sh
zip entrega.zip analizador.l documento_descriptivo.pdf
unzip -l entrega.zip
```

El primero crea el ZIP y el segundo permite revisar su contenido: deben estar sólo esos dos archivos. Usa un nombre de ZIP nuevo si ya tienes otro, porque `zip` actualiza archivos existentes. No agregues `lex.yy.c`, el ejecutable, el README ni las pruebas. El documento descriptivo aún debes prepararlo; los PDF de la profesora son referencias, no tu documento de entrega.
