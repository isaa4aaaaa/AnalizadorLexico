# Guía de trabajo: analizador léxico con Flex

Esta guía transforma el enunciado en una ruta de trabajo. No es un documento listo para entregar ni contiene las expresiones regulares o el código resueltos. Su propósito es ayudarte a tomar cada decisión, escribirla con tus palabras y comprobarla antes de avanzar.

## 1. Qué debe existir al final

El producto tiene dos partes:

1. Un único programa fuente definitivo de Flex, con el código C necesario para administrar tablas, tokens, errores y la entrada desde archivo.
2. Un documento de entrega con descripción del problema, expresiones regulares, análisis y planificación, diseño de estructuras y algoritmos, pruebas, instrucciones de ejecución y conclusiones individuales.

Antes de programar, convierte el enunciado en una lista verificable:

- reconocer las nueve clases, numeradas de 0 a 8;
- conservar los valores exactos de cada catálogo;
- registrar identificadores sin duplicarlos;
- registrar cada aparición de una cadena o real, incluso si se repite;
- convertir una constante entera a su valor numérico;
- ignorar comentarios de línea y de bloque;
- informar errores con su número de línea y continuar;
- aceptar por línea de comandos el archivo fuente;
- mostrar las tres tablas y la secuencia completa de tokens al terminar.

Pregunta de control: ¿cada punto anterior puede señalarse en una función, regla o prueba concreta de tu diseño?

## 2. Decisiones que conviene aclarar primero

El enunciado deja algunos bordes abiertos. Anota tu interpretación y, si es posible, confírmala con la profesora antes de fijar las expresiones regulares:

- El primer ejemplo de identificador parece tener un espacio antes de `_I`. ¿Es un error tipográfico? ¿Sería compatible ese espacio con la descripción formal?
- Las constantes enteras usan `n` y `p`, pero los reales de ejemplo usan `-` y no muestran `+`. ¿Qué signos exactos aceptarás para cada clase?
- ¿La notación científica exige una parte decimal o también permite algo como `32e-3`, como indica el ejemplo?
- Dentro de `<...>`, ¿un `>` sin mecanismo de escape siempre termina la cadena?
- ¿Qué significa exactamente que `@n`, `@f`, `@d` y `@t` pueden referenciar valores? ¿Son secuencias de dos caracteres válidas dentro de la cadena, componentes separados o sustituciones que debe realizar el analizador?
- ¿Qué debe informarse ante `/*` sin cierre al final del archivo o `<` sin cierre?
- Cuando un prefijo parece iniciar un token válido pero después falla, ¿qué fragmento se reportará como un solo error para poder continuar?

Estas decisiones pertenecen al análisis. Documentarlas evita que la expresión regular, la acción y la prueba contradigan entre sí.

## 3. Construcción de las expresiones regulares

Trabaja primero en papel o en una tabla, una clase a la vez. Para cada clase completa cuatro columnas: lenguaje en palabras, bloques pequeños, expresión completa y fronteras o casos inválidos.

### Clase 0: palabras reservadas

Hay 17 palabras y cada una tiene un valor de catálogo inamovible, de 0 a 16. Pregúntate:

- ¿Conviene una regla por palabra o una regla conjunta con búsqueda en el catálogo?
- ¿Cómo garantizas que el valor guardado coincide con la posición dada, sin depender de un orden accidental?
- ¿Distinguirás mayúsculas y minúsculas? ¿Qué exige el enunciado?

### Clase 1: identificadores

Descompón la forma en prefijo, cuerpo y sufijo. Después responde:

- ¿Puede el cuerpo estar vacío?
- ¿El guion bajo forma parte del cuerpo y también de ambos delimitadores?
- ¿Cómo expresarás el límite total de 32 caracteres contando prefijo y sufijo?
- ¿Qué harás con una forma sintácticamente parecida que mida 33 caracteres: dividirla en tokens o reportarla completa como error?

No cierres esta clase hasta calcular cuántos caracteres como máximo puede ocupar sólo el cuerpo.

### Clases 2 a 5: catálogos de operadores y símbolos

Copia en tu diseño el orden exacto de las tablas del enunciado. Luego marca los lexemas que son prefijo de otro lexema.

- ¿Qué regla elegiría Flex cuando dos coincidencias empiezan en la misma posición?
- Si las coincidencias tienen la misma longitud, ¿qué papel tiene el orden de las reglas?
- ¿Qué orden hace visible tu intención para `&*` y `&*&`, o para otros pares solapados?
- ¿Puedes usar una función común para encontrar el índice del lexema en su catálogo?

### Clase 6: constantes enteras

Separa tres casos conceptuales: cero, positivo distinto de cero y negativo.

- ¿Cómo impides aceptar las formas positiva o negativa de cero si sólo `0i` representa ese valor?
- ¿Aceptarás ceros iniciales en números no nulos? Si el texto no lo dice, registra tu decisión.
- ¿Qué función de C convierte el texto a número y cómo detectarás desbordamiento?
- ¿El sufijo `i` debe excluirse antes de convertir? ¿Cómo manejarás `p` y `n`?

### Clase 7: constantes reales

Construye y prueba por separado: forma decimal, exponente y signo.

- A partir de los ejemplos, ¿cuántos dígitos se exigen a cada lado del punto?
- ¿Qué partes son opcionales en `32e-3`?
- ¿El exponente admite `e` y `E`, y qué signos admite?
- ¿Una secuencia que también parece el comienzo de un entero podría capturarse incorrectamente?
- Como el dato se almacena como cadena, ¿necesitas convertirlo a `double`?

### Clase 8: constantes cadena

- ¿Cómo representas el intervalo ASCII 32 a 126 sin permitir que el delimitador final sea consumido como contenido?
- ¿La cadena vacía `<>` es válida según “0 o más”?
- ¿Se permiten saltos de línea? Compara su código ASCII con el intervalo indicado.
- ¿Las secuencias con `@` necesitan reglas especiales o ya pertenecen al intervalo general?
- ¿Guardarás los delimitadores `<` y `>` o sólo el contenido? Especifica tu decisión en el diseño.

### Espacios, comentarios y errores

- Diseña una regla para uno o más espacios, tabuladores o saltos de línea cuya acción sea descartarlos.
- Para comentarios de bloque, compara una sola expresión regular con un estado exclusivo de Flex. ¿Cuál permite detectar con claridad un comentario sin cerrar y mantener bien el número de línea?
- Coloca al final una estrategia de error que siempre consuma al menos un carácter. ¿Por qué esa propiedad garantiza progreso?

## 4. Diseño del programa en C

Diseña los datos antes de escribir acciones de Flex. Dibuja cada estructura y explica el propósito de cada campo.

### Token

Necesitas conservar clase y valor. Preguntas de diseño:

- ¿Ambos caben en enteros para todas las clases?
- ¿Cómo crecerá la secuencia de tokens si desconoces su longitud?
- ¿Qué función agregará un token sin repetir la lógica en nueve acciones?

### Tabla de símbolos

Cada entrada contiene posición, nombre y tipo entero inicialmente `-1`.

- ¿La posición necesita almacenarse o puede deducirse del índice? Aunque la deduzcas, ¿cómo cumplirás y explicarás el campo pedido?
- ¿Copiarás el identificador a memoria propia o conservarás un apuntador a `yytext`? Investiga qué ocurre con `yytext` después de la siguiente coincidencia.
- Para el tamaño esperado de la tarea, ¿una búsqueda lineal hace el diseño más sencillo de comprobar? Explica su costo y por qué es suficiente, o justifica otra técnica.
- Diseña una sola operación “buscar o insertar” que devuelva la posición en ambos casos.

### Tablas de literales

Cada entrada contiene posición y dato como cadena. Habrá una tabla para reales y otra para cadenas.

- ¿Por qué la operación de inserción no debe buscar duplicados?
- ¿Pueden ambas tablas reutilizar la misma estructura y la misma función de inserción?
- ¿Quién reserva, copia y libera cada dato?

### Catálogos fijos

Las palabras, operadores y símbolos ya tienen valores dados. Una representación útil debe preservar el orden y permitir convertir un lexema en índice.

- ¿Usarás arreglos de cadenas en el orden del enunciado?
- ¿Una función de búsqueda puede servir para los cinco catálogos si recibe arreglo y longitud?
- ¿Cómo evitarás escribir manualmente una longitud que luego se desactualice?

### Memoria dinámica y manejo de fallos

Para cada arreglo dinámico define tamaño usado y capacidad reservada.

- ¿Qué condición indica que debe crecer?
- ¿Qué política de crecimiento evita reservar por cada elemento?
- ¿Usarás un apuntador temporal al redimensionar para no perder el bloque original si falla?
- ¿Qué función centralizará la copia de cadenas si tu entorno no garantiza una variante particular?
- Enumera todo lo que debe liberarse al final y también en las salidas por error.

## 5. Flujo completo

Escribe primero este flujo en comentarios y conviértelo gradualmente en C:

1. Validar la cantidad de argumentos.
2. Abrir el archivo indicado y comprobar el resultado.
3. Asignar el flujo de entrada que leerá Flex.
4. Inicializar las estructuras que lo requieran.
5. Ejecutar el análisis hasta fin de archivo, acumulando resultados.
6. Cerrar el archivo.
7. Mostrar tabla de símbolos, literales reales, literales cadena y tokens.
8. Liberar toda la memoria propia.
9. Devolver un estado que distinga éxito, uso incorrecto y fallo de archivo o memoria.

Pregunta de control: si ocurre un error léxico recuperable, ¿debe interrumpirse alguno de esos pasos?

## 6. Orden de implementación recomendado

Cada etapa debe terminar con una prueba pequeña que todavía funcione antes de añadir la siguiente:

1. Crear el esqueleto de Flex y comprobar que lee el archivo dado por línea de comandos.
2. Activar y comprobar el conteo de líneas.
3. Ignorar delimitadores y reconocer errores carácter por carácter.
4. Definir tipos y operaciones de almacenamiento, todavía sin conectarlos a todas las reglas.
5. Implementar catálogos fijos y sus búsquedas.
6. Añadir las clases 0 y 2 a 5, verificando valores exactos.
7. Añadir identificadores con “buscar o insertar”.
8. Añadir enteros y comprobar la conversión y el cero.
9. Añadir reales y cadenas con inserción incondicional.
10. Añadir comentarios de línea y bloque, incluida la llegada inesperada al fin del archivo.
11. Imprimir resultados y liberar memoria.
12. Ejecutar pruebas de integración y revisar la salida con sanitizadores o herramientas equivalentes.

Este orden separa los problemas: primero el recorrido, luego el almacenamiento, después las reglas y finalmente los casos con estado y memoria.

## 7. Matriz mínima de pruebas

No pruebes sólo ejemplos válidos. Para cada fila escribe antes el resultado esperado: tokens, posiciones de tablas, errores y línea.

| Familia | Casos que debes preparar |
|---|---|
| Reservadas | las 17; una con mayúscula; reservadas consecutivas |
| Identificador | cuerpo mínimo; longitud 32; longitud 33; repetido; carácter prohibido |
| Asignación | los 6; varios consecutivos; prefijos incompletos |
| Relacionales | los 6; pares con prefijo parecido; secuencia inválida |
| Aritméticos | los 7; atención especial a lexemas solapados |
| Especiales | los 7; combinaciones sin espacios |
| Enteros | cero; positivo; negativo; cero con signo; sin `i`; carácter extra; valor enorme |
| Reales | cada forma de los ejemplos; exponentes; signos; punto sin dígitos; exponente incompleto |
| Cadenas | vacía; espacios; secuencias `@`; límite ASCII; sin cierre; salto de línea |
| Comentarios | línea; bloque; varias líneas; marcadores dentro del comentario; bloque sin cierre |
| Integración | tokens sin espacios; líneas mezcladas; errores entre tokens válidos; archivo vacío |

Pruebas estructurales esenciales:

- El mismo identificador dos veces debe producir la misma posición y una sola entrada.
- El mismo real o cadena dos veces debe producir dos posiciones y dos entradas.
- Tras un error, un token válido posterior debe reconocerse.
- Los números de línea deben seguir correctos después de comentarios y cadenas rechazadas.

## 8. Cómo construir el documento de entrega

Redáctalo con tus propias decisiones y resultados:

1. **Descripción del problema.** Explica qué información transforma el analizador y las restricciones de cada clase. Incluye tu tabla final de expresiones regulares y los casos frontera. No copies el enunciado.
2. **Propuesta y fases.** En análisis incluye actividades, participantes y calendario. En diseño presenta diagramas o tablas de campos, crecimiento, propiedad de memoria, búsqueda e inserción. En pruebas presenta casos, resultados esperados y obtenidos.
3. **Ejecución.** Indica requisitos, comando de generación con Flex, compilación del C generado, forma de invocación y archivos o secciones de salida.
4. **Conclusiones.** Una por participante: decisiones tomadas, dificultades reales, evidencia de aprendizaje y posibles mejoras.

La fecha indicada por el enunciado es el 29 de septiembre de 2026. Reserva tiempo antes para probar el paquete final desde una carpeta limpia.

## 9. Sesión de trabajo sugerida

Usa `analizador.l` como cuaderno de programación. En cada bloque:

1. contesta los comentarios con frases breves;
2. escribe la parte mínima de código correspondiente;
3. compila;
4. ejecuta uno o dos casos pequeños;
5. conserva la prueba que descubrió un error;
6. sólo entonces pasa al siguiente bloque.

Cuando quieras ayuda, muestra el bloque que escribiste, el comando usado, la entrada mínima y el resultado observado. Así podremos razonar sobre una decisión concreta sin sustituir tu trabajo.
