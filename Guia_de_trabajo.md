# Guía de trabajo: analizador léxico con Flex

> **Actualización del 29/09/2026:** el programa completo está en `codigo/analizador.l`, sin depender de otros archivos fuente. Consulta `codigo/README.md` para revisar su funcionamiento y los comandos individuales. Esta guía conserva el proceso de aprendizaje anterior; el cuaderno original está en `apuntes/analizador_guiado.l.txt` y la versión anterior separada en módulos está en `apuntes/version_modular/`. Las menciones históricas a código pendiente o a varios archivos no describen la entrega actual.

Esta guía transforma el enunciado en una ruta de trabajo. No es un documento listo para entregar. La revisión del 28/09 conserva tus respuestas y añade correcciones explicadas a tus expresiones regulares; la implementación en C queda a tu cargo.

> **Cómo leer la revisión:** tus respuestas originales se conservan como registro de trabajo y algunas contienen errores. Los bloques «Revisión» y la sección 10 explican las correcciones. En `analizador.l`, cada bloque «REVISIÓN / PSEUDOCÓDIGO» propone pasos en español para que tú escribas la implementación. El PDF de la guía anterior corresponde a la versión del 22/09 y no contiene esta revisión.

## 1. Qué debe existir al final

El producto tiene dos partes:

1. El programa fuente definitivo de Flex, con el código C necesario para administrar tablas, tokens, errores y la entrada desde archivo. Organizarlo en un solo `.l` es una propuesta sencilla, no una exigencia de entregar un único archivo fuente.
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
    Error tipográfico, sería incompatible para reducir complejidad inecesaria
- Las constantes enteras usan `n` y `p`, pero los reales de ejemplo usan `-` y no muestran `+`. ¿Qué signos exactos aceptarás para cada clase?
    Eh, no los de ejemplo no usan "-", alucinaste esto, "n" es para numeros negativos y "p" para positivos, dentro de eso solamente pueden existir numeros enteros.
- ¿La notación científica exige una parte decimal o también permite algo como `32e-3`, como indica el ejemplo?
    Como muestra el ejemplo, puede ser tanto un decimal como notacion cientifica, la "e" puede ser minuscula o mayuscula es indistinto
- Dentro de `<...>`, ¿un `>` sin mecanismo de escape siempre termina la cadena?
    Si, no puedes tener "<>>" ni "<<>" ni nada similar, quiza podriamos agregar que se use / para escapar y que funcione pero eso seria extra de lo establecido en el pdf.
- ¿Qué significa exactamente que `@n`, `@f`, `@d` y `@t` pueden referenciar valores? ¿Son secuencias de dos caracteres válidas dentro de la cadena, componentes separados o sustituciones que debe realizar el analizador?
    Sustituciones, es similar a como en C se usa "%d" o cosas asi, literal es lo mismo, no se si el analizador lo debe sustituir o sera despues en el proceso de compilacion pero a eso se refiere. Las letras n, f, d y t no recuerdo que representan, quiza podriamos mejor usar la misma notacion que en C
- ¿Qué debe informarse ante `/*` sin cierre al final del archivo o `<` sin cierre?
    Pues un error diciendo que no se cerro "/*" o "<"
- Cuando un prefijo parece iniciar un token válido pero después falla, ¿qué fragmento se reportará como un solo error para poder continuar?
    No entiendo, si hay un token invalido se muestra la linea en la que fallo y donde fallo y ya 

Estas decisiones pertenecen al análisis. Documentarlas evita que la expresión regular, la acción y la prueba contradigan entre sí.

## 3. Construcción de las expresiones regulares

Trabaja primero en papel o en una tabla, una clase a la vez. Para cada clase completa cuatro columnas: lenguaje en palabras, bloques pequeños, expresión completa y fronteras o casos inválidos.

### Clase 0: palabras reservadas

Hay 17 palabras y cada una tiene un valor de catálogo inamovible, de 0 a 16. Pregúntate:

- ¿Conviene una regla por palabra o una regla conjunta con búsqueda en el catálogo?
    Quiza una regla por palabra para evitar que se tenga que acceder al catalogo por cada palabra que se analiza. aunque no se que sea mas eficiente, quiza una simple comparacion y si se encuentra cierta palabra pues ya se busca o no se.
- ¿Cómo garantizas que el valor guardado coincide con la posición dada, sin depender de un orden accidental?
    Que, no necesitas necesariamente eso, o si? podrias solo ir agregando valores mientras aparecen en el codigo. por ejemplo, si tenemos palabra reservada identificador entero podriamos registrar algo como (0,x) (1,x) (6,x) y ese seria el orden no? o no?
- ¿Distinguirás mayúsculas y minúsculas? ¿Qué exige el enunciado?
    No menciona, solamente dice que puede tener tanto minusculas como mayusculas, yo digo que si habra que distinguir de modo que no sea lo mismo "variable" que "Variable"

### Clase 1: identificadores

Descompón la forma en prefijo, cuerpo y sufijo. Después responde:

Prefijo: "I_"
Cuerpo: [a-zA-Z0-9]{1-28}

> **Revisión:** tu propuesta original queda arriba. El cuerpo corregido es `[a-zA-Z0-9_]{1,28}`: falta `_`, permitido explícitamente, y el intervalo lleva coma. La expresión completa es `"I_"[a-zA-Z0-9_]{1,28}"_I"`. Tu máximo 28 es correcto: 32 menos los cuatro caracteres de prefijo y sufijo. El mínimo 1 conserva tu decisión; el enunciado no lo fija. `I_hola__I` e `I_hola_I` son distintos, pero ambos son válidos.
Sufijo: "_I"

- ¿Puede el cuerpo estar vacío?
    No
- ¿El guion bajo forma parte del cuerpo y también de ambos delimitadores?
    Obvio no, solamente es la forma de definir el limite, es distinto "I_hola__I" a "I_hola_I"
- ¿Cómo expresarás el límite total de 32 caracteres contando prefijo y sufijo?
    Con un rango tipo: [RegExcuerpo]{1-28}
- ¿Qué harás con una forma sintácticamente parecida que mida 33 caracteres: dividirla en tokens o reportarla completa como error?
    Reportarla completa como error, no puede sobrepasar ese limite

No cierres esta clase hasta calcular cuántos caracteres como máximo puede ocupar sólo el cuerpo.
    El cuerpo puede ocupar maximo 28 caracteres

### Clases 2 a 5: catálogos de operadores y símbolos

Copia en tu diseño el orden exacto de las tablas del enunciado. Luego marca los lexemas que son prefijo de otro lexema.

RegEx:

    Asignacion:
        [:][=+-*/%]

    Relacionales:
        [+-][i{0-1}q]
        [:|d/][i]

    Aritmeticos:
        [&][+-*/]|[&][*]|[%][&]|[*][&]

    Especiales:
        [@][>]|[$]{2}|[#][?]|[:]{2}[=]|[?][=]|[%][~]|[+]

> **Revisión de tus cuatro patrones:** las propuestas originales quedan arriba. Usa estas versiones corregidas (notación Flex):
>
> - Asignación: `":"[-=+/%*]`. El guion al inicio es literal; en tu patrón estaba entre otros caracteres y podía formar un rango inválido.
> - Relacionales: `[+-]i?q|":i"|"d/i"`. Primero un signo, luego una `i` opcional y finalmente `q`; o uno de los otros dos lexemas completos. `[i{0-1}q]` no aplica una repetición y `[:|d/]` selecciona sólo un carácter.
> - Aritméticos: `"&&*"|"&%&"|"&*&"|"&+"|"&-"|"&*"|"&/"`. Tu propuesta duplicaba `&*`, omitía `&&*` y separaba `%&` y `*&` de su `&` inicial. Las comillas hacen literal cada operador.
> - Especiales: tu expresión es correcta. Se puede leer más fácilmente como `"@>"|"$"|"#?"|"::="|"?="|"%~"|"+"`.
>
> Flex elige la coincidencia más larga: `&*&` se reconoce entero aunque `&*` esté antes. Sólo en empate importa el orden. Por ejemplo, con reglas `"if"` y `[a-z]+`, ambas consumen dos caracteres en `if`: gana la primera regla. Ese patrón genérico sirve aquí sólo como ejemplo, no como definición de identificadores de la tarea.


- ¿Qué regla elegiría Flex cuando dos coincidencias empiezan en la misma posición?
    No entiendo
- Si las coincidencias tienen la misma longitud, ¿qué papel tiene el orden de las reglas?
    Tampoco entiendo eso a que te refieres da ejemplos
- ¿Qué orden hace visible tu intención para `&*` y `&*&`, o para otros pares solapados?
    Mmmmmm ya entiendo, no pues una vez que se identifica "&*" se revisa si se encuentra "&*&" o no
- ¿Puedes usar una función común para encontrar el índice del lexema en su catálogo?
    Pues, si? una tipo busqueda? o algo asi.

### Clase 6: constantes enteras

Separa tres casos conceptuales: cero, positivo distinto de cero y negativo.

    Cero: [0][i]

    Positivo: [p][1-9]+[i]

    Negativo: [n][1-9]+[i]

> **Revisión:** cero `0i`, positivo `p[1-9][0-9]*i`, negativo `n[1-9][0-9]*i`. Unidos: `0i|[pn][1-9][0-9]*i`. Tu `[1-9]+` impedía cualquier cero, incluso en `p10i` o `n205i`. Basta exigir un primer dígito no nulo y permitir después cero o más dígitos cualesquiera. Se conservan tus decisiones de no aceptar ceros iniciales y de usar `p/n` para no nulos. Este patrón por sí solo no evita que un escáner divida un texto inválido: `p0i` requiere una regla de error que lo consuma completo si ésa es tu política.


- ¿Cómo impides aceptar las formas positiva o negativa de cero si sólo `0i` representa ese valor?
    pues no puede tener nada antes si no no cumple o que, con un "?"
- ¿Aceptarás ceros iniciales en números no nulos? Si el texto no lo dice, registra tu decisión.
    no, sin ceros iniciales
- ¿Qué función de C convierte el texto a número y cómo detectarás desbordamiento?
    atoi, no se como detectar desbordamiento
- ¿El sufijo `i` debe excluirse antes de convertir? ¿Cómo manejarás `p` y `n`?
    Si, se excluye. para "p" y "n" solo se vuelven "+" y "-" respectivamente

### Clase 7: constantes reales

Construye y prueba por separado: forma decimal, exponente y signo.

decimal: [0-9]*[.][1-9]+
exponente: [[[0-9]*[.][1-9]+]|[0-9]+][e|E][-]{0-1}[1-9]
signo: [-]{0-1}[[0-9]*[.][1-9]+]|[[[0-9]*[.][1-9]+]|[0-9]+][e|E][-]{0-1}[1-9]

> **Revisión por partes:** decimal `[0-9]*[.][0-9]+`; exponente `[eE]-?[0-9]+`; real completo `-?([0-9]*[.][0-9]+([eE]-?[0-9]+)?|[0-9]+[eE]-?[0-9]+)`.
>
> La primera alternativa exige punto y permite exponente opcional; la segunda admite mantisa entera pero exige exponente. Así `32` solo no es un real, pero `32e-3` sí. El menos inicial se aplica a ambas alternativas porque están agrupadas con paréntesis. `?` sustituye el intervalo opcional; `{0,1}` también sirve, `{0-1}` no. `[eE]` no incluye la barra vertical que sí aceptaba `[e|E]`. `[0-9]+` permite ceros y exponentes de varios dígitos, como `1e10` y `1e0`.
>
> Se conservan tus decisiones de sólo menos opcional y al menos un dígito tras el punto: `+1.2`, `1e+2` y `1.` quedan fuera como lexemas completos. Son supuestos de diseño donde el enunciado no especifica todas las variantes; no se deducen automáticamente de las reglas de C.

- A partir de los ejemplos, ¿cuántos dígitos se exigen a cada lado del punto?
    Del lado izquiero puede ser ninguno tipo [.23], del derecho si tiene que tener por lo menos 1
- ¿Qué partes son opcionales en `32e-3`?
    El signo
- ¿El exponente admite `e` y `E`, y qué signos admite?
    aja, y un menos antes del numero y despues de E
- ¿Una secuencia que también parece el comienzo de un entero podría capturarse incorrectamente?
    mmmm, pues el 0 pero no porque a fuerzas se necesita que sea seguido por un punto. Para el resto de numeros no porque no tendrian "n" ni "p"
- Como el dato se almacena como cadena, ¿necesitas convertirlo a `double`?
    Si, no se como. 

### Clase 8: constantes cadena

RegEx:
    [<][a-zA-Z0-9ASCII]+[@][nfdt][>]

> **Revisión:** siguiendo el intervalo ASCII y tomando el primer `>` como cierre: `"<"[\x20-\x3D\x3F-\x7E]*">"`.
>
> `\x20..\x3D` cubre 32..61 y `\x3F..\x7E` cubre 63..126: se excluye 62, que es `>`. `*` permite cero caracteres; por eso `<>` es válida. El salto de línea (10) y el tabulador (9) quedan fuera. Escribir `ASCII` dentro de corchetes sólo añade esas letras, no todo el intervalo. Tu patrón también obligaba a tener un marcador `@n/@f/@d/@t` al final: el enunciado dice que se pueden usar, no que sean obligatorios. Ya están admitidos como texto por el intervalo y pueden aparecer varias veces o en cualquier posición.
>
> **Sobre tu decisión de prohibir también `<` interno:** el enunciado incluye ASCII 60, por lo que esa prohibición añade una restricción. Con la lectura literal anterior `<<>` es una cadena válida con contenido `<`. Si la profesora confirma tu interpretación más restrictiva, el patrón alternativo sería `"<"[\x20-\x3B\x3D\x3F-\x7E]*">"`, que excluye 60 y 62. No se añaden escapes nuevos. `<>>` se reconoce como la cadena vacía `<>` seguida de un `>` inválido, no como una cadena válida completa.

- ¿Cómo representas el intervalo ASCII 32 a 126 sin permitir que el delimitador final sea consumido como contenido?
    Eh, no se? no entendi eso
- ¿La cadena vacía `<>` es válida según “0 o más”?
    no, tiene que tener por lo menos algo
- ¿Se permiten saltos de línea? Compara su código ASCII con el intervalo indicado.
    Creo que si???? No es el valor 10?? 
- ¿Las secuencias con `@` necesitan reglas especiales o ya pertenecen al intervalo general?
    Pues creo que pertenecen al intervalo general, creo....... no se!
- ¿Guardarás los delimitadores `<` y `>` o sólo el contenido? Especifica tu decisión en el diseño.
    Solamente el contenido, es inutil guardar "<>" simplemente nos sirven para identificar

### Espacios, comentarios y errores

Se tendrían que buscar los identificadores, no entiendo que tengo que hacer aca.

- Diseña una regla para uno o más espacios, tabuladores o saltos de línea cuya acción sea descartarlos.
- Para comentarios de bloque, compara una sola expresión regular con un estado exclusivo de Flex. ¿Cuál permite detectar con claridad un comentario sin cerrar y mantener bien el número de línea?
- Coloca al final una estrategia de error que siempre consuma al menos un carácter. ¿Por qué esa propiedad garantiza progreso?

## 4. Diseño del programa en C

Diseña los datos antes de escribir acciones de Flex. Dibuja cada estructura y explica el propósito de cada campo.

### Token

Necesitas conservar clase y valor. Preguntas de diseño:

- ¿Ambos caben en enteros para todas las clases?
    No, como dije antes algunos son caracteres
- ¿Cómo crecerá la secuencia de tokens si desconoces su longitud?
    De manera dinámica, no puede ser estática tiene que ser una estructura de datos dinámica
- ¿Qué función agregará un token sin repetir la lógica en nueve acciones?
    no entiendo esto

### Tabla de símbolos

Cada entrada contiene posición, nombre y tipo entero inicialmente `-1`.

- ¿La posición necesita almacenarse o puede deducirse del índice? Aunque la deduzcas, ¿cómo cumplirás y explicarás el campo pedido?
    del indice
- ¿Copiarás el identificador a memoria propia o conservarás un apuntador a `yytext`? Investiga qué ocurre con `yytext` después de la siguiente coincidencia.
    no entiendo
- Para el tamaño esperado de la tarea, ¿una búsqueda lineal hace el diseño más sencillo de comprobar? Explica su costo y por qué es suficiente, o justifica otra técnica.
    ehh que? si creo que si es lo mas sencillo
- Diseña una sola operación “buscar o insertar” que devuelva la posición en ambos casos.

### Tablas de literales

Cada entrada contiene posición y dato como cadena. Habrá una tabla para reales y otra para cadenas.

- ¿Por qué la operación de inserción no debe buscar duplicados?
    porque no, eso lo debe hacer una funcion especifica
- ¿Pueden ambas tablas reutilizar la misma estructura y la misma función de inserción?
    eh, si?
- ¿Quién reserva, copia y libera cada dato?
    eh una funcion.....?

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

## 10. Revisión explicada y decisiones de implementación — 28/09/2026

### Qué tomar de cada referencia

- [Enunciado](DescripProgAnalizadorLex_27-1.pdf), pp. 1–3: manda sobre clases, valores, literales, comentarios y recuperación. Los literales reales y cadena se insertan **cada vez**; los enteros guardan su valor numérico directamente.
- [Tema 2](Tema-2-Analisis-Lexico.pdf), pp. 1–3: crear tablas, reconocer, actualizar, generar token y continuar. P. 5: registros y nombres mediante apuntadores; pp. 6–7: fronteras y errores; pp. 9–11: ejemplos de tablas y tokens.
- [Uso de LEX](DescripcionUsoLEX.pdf), sección 2.6: tres secciones del archivo, macros, reglas, `yytext`, `yyin` y llamada a `yylex`. Su tabla de operadores explica la diferencia entre grupos, clases y repeticiones.

Tema 2 presenta una versión general que puede buscar literales repetidos. Esa búsqueda **no corresponde a esta tarea**: no se hace ni en otra función ni antes de insertar. Tampoco copies los números de clase o el catálogo de palabras de C usados en sus ejemplos: aquí manda el catálogo del enunciado.

Mi primera guía imponía por redacción un “único programa fuente”. Lo correcto es entregar el código fuente definitivo; usar un solo `.l` es una propuesta de organización, no una restricción adicional.

### Correcciones a tus respuestas sobre el lenguaje

1. **Enteros y reales usan signos diferentes.** En la página 1 del enunciado, la fila de reales sí muestra `-2.2`, `32e-3` y `-4.4E2`. Tu explicación de `n/p` es correcta para enteros, pero no se extiende a reales.
2. **El guion bajo sí pertenece al cuerpo del identificador.** El texto lo permite expresamente y el ejemplo `I_valor_mayor_I` lo utiliza dentro del cuerpo.
3. **Cadena vacía y saltos.** “0 o más” permite `<>`. ASCII 10 está fuera del intervalo 32..126. Una cadena puede tener espacios, pero no un salto real de línea ni tabulador según esta definición.
4. **Marcadores con @.** Conservaremos `@n`, `@f`, `@d` y `@t` en el dato, sin interpretarlos ni sustituirlos en esta etapa. Ninguno de estos documentos define sus significados precisos ni pide implementar un formateador. No inventaremos esos significados ni cambiaremos el lenguaje a la notación de C.
5. **Palabra con tilde.** El catálogo de la página 2 dice `decisión`, no `decision`. El valor es 4. Los otros lexemas y posiciones que copiaste en el catálogo corresponden al enunciado.
6. **Errores recuperables.** Reportar la línea y detenerse en el primer error incumple la tarea. Después de consumir el fragmento inválido hay que continuar hasta EOF, excepto fallos que impidan trabajar, como falta de memoria.
7. **Mayúsculas/minúsculas.** Conservamos tu decisión de distinguirlas. Eso también mantiene las reservadas con la escritura exacta del catálogo.

### Lexema, token, fila e índice: un ejemplo pequeño

El lexema es el texto reconocido. El token tiene sólo clase y valor. Cuando valor es una posición, el texto vive en otra tabla.

Supón esta entrada, con tablas inicialmente vacías:

`int I_x_I := n25i I_x_I 1.0 1.0 <hola> <hola>`

| Lexema | Token esperado | Efecto |
|---|---|---|
| int | (0,10) | Valor fijo del catálogo; no se inserta |
| I_x_I | (1,0) | Símbolo nuevo en posición 0, tipo -1 |
| := | (2,0) | Valor fijo de asignación |
| n25i | (6,-25) | Entero numérico, sin tabla literal |
| I_x_I | (1,0) | Reutiliza símbolo; no inserta otra fila |
| 1.0 | (7,0) | Guarda texto 1.0 en reales |
| 1.0 | (7,1) | Guarda otra entrada de reales |
| <hola> | (8,0) | Guarda contenido hola en cadenas |
| <hola> | (8,1) | Guarda otra entrada de cadenas |

Los dos campos pueden ser enteros. No necesitan contener letras ni convertirse desde una representación textual de token. Las posiciones de cada tabla son independientes y no dependen del número total de tokens.

### Qué significan las estructuras y los apuntadores

Una estructura de C reúne campos con nombres. Una fila de símbolos reúne posición, nombre y tipo. Un arreglo de esas estructuras representa la tabla.

El campo nombre guarda la dirección de una cadena propia. No es necesario construir una matriz rectangular ni reservar 32 caracteres para todos los nombres. Cuando una función copia el texto y la tabla conserva esa copia, decimos que la tabla es dueña de la memoria: debe liberarla cuando ya no la use.

Para cada colección dinámica necesitas:

| Dato | Significado | Ejemplo |
|---|---|---|
| Apuntador a elementos | Dirección del bloque con las filas | Memoria reservada para estructuras |
| Usados | Filas que ya contienen datos válidos | 3 |
| Capacidad | Filas que caben en el bloque | 8 |

Estado inicial: apuntador nulo y ambos contadores en cero. Antes de escribir la primera fila se reserva espacio. Sólo se recorren las filas usadas; capacidad no es cantidad de elementos existentes.

Reales y cadenas pueden usar el mismo tipo de fila porque ambos guardan texto. Son dos colecciones diferentes. Los tokens usan otro tipo de fila con dos enteros.

### Contratos de funciones: qué quiere decir “recibe y devuelve”

“Recibe” son los datos que necesita; “devuelve” es la respuesta que le sirve a quien la llamó. “Modifica” describe cambios en las tablas. La implementación paso a paso está junto a cada sección de `analizador.l`.

| Función propuesta | Recibe | Devuelve / modifica |
|---|---|---|
| agregar_token | Clase y valor | Éxito/fallo; agrega a secuencia |
| buscar_en_catalogo | Texto, catálogo y cantidad | Índice o -1; no modifica |
| buscar_o_insertar_simbolo | Nombre | Posición existente o nueva |
| insertar_literal | Tabla elegida y texto | Nueva posición, siempre |
| copiar texto | Origen y longitud | Dirección de copia propia |
| asegurar espacio | Colección a modificar | Éxito/fallo; aumenta capacidad si hace falta |
| imprimir_resultados | Colecciones | Muestra datos sin cambiarlos |
| liberar_recursos | Colecciones | Libera copias y arreglos |

No uses verdadero/falso para devolver una posición: perderías qué fila encontraste y confundirías posición 0 con falso. La comparación de cadenas se hace por contenido, con `strcmp`; comparar apuntadores con `==` no compara el texto.

### Memoria, conversiones y encabezados de C

- `stdio.h` declara entrada/salida. `stdin` es un flujo, no el encabezado `stdin.h`.
- `stdlib.h` declara reserva, liberación y `strtol`; `string.h` ofrece operaciones de cadenas.
- `errno.h` y `limits.h` ayudan a comprobar fallos de conversión y límites del entero elegido.
- Tu respuesta `n+1` para copiar una cadena de longitud n es correcta: el byte adicional contiene el terminador nulo.
- `yytext` es el texto de la coincidencia actual y puede cambiar después. Copia durante la acción lo que deba sobrevivir. `free` no copia; no debes liberar `yytext`.
- Reserva usando un apuntador temporal para `realloc`: si falla, conserva el original para poder liberar o manejar el error.
- Para enteros, transforma `n/p` en signo y excluye la `i`, convierte con `strtol` y comprueba final de conversión, `ERANGE` y rango de `int`. `atoi` no sirve para controlar esos fallos de forma fiable.
- Los reales **no** se convierten a `double`: el enunciado pide el dato como cadena.
- Sólo libera memoria reservada por ti: nombres, datos de literales y arreglos dinámicos. Los catálogos de textos fijos no necesitan esa liberación.

### Espacios, comentarios, líneas y fin del archivo

Aquí no buscas identificadores: reconoces texto que se descarta.

- Espacios: `[ \t\n]+`. Consumir el bloque y no generar token.
- Comentario de línea: `"//"[^\n]*`. Consumir desde las barras hasta antes del salto o hasta EOF.
- Comentario de bloque: entrar a un estado exclusivo al ver la apertura; allí sólo descartar contenido y buscar el cierre. Al cerrar, volver al estado normal. Si llega EOF antes, reportar la línea donde abrió.
- La opción `yylineno` permite contar saltos automáticamente. No los vuelvas a sumar manualmente.
- La opción `noyywrap` evita implementar una función de continuación entre archivos.
- La regla genérica final consume un carácter desconocido, informa línea y continúa. No tiene que encontrar un token para avanzar.

Para la entrada usa `yyin`. Para iniciar el análisis llama a `yylex`. `yytext` no es el archivo. En esta tarea puedes hacer que todas las acciones acumulen tokens sin retornar uno por uno, de modo que una llamada a `yylex` recorra todo el archivo.

Los ejemplos de Uso de LEX tienen detalles de C que no conviene copiar literalmente: `fprintf` necesita un flujo destino; un flujo abierto con `fopen` se cierra con `fclose`; `main` debe declarar su retorno `int`. Sirven para entender la organización, no como implementación completa con validación de errores.

### Recuperación sin perder componentes válidos

Un patrón de token válido no es un validador automático de todo el texto cercano. Flex puede reconocer prefijos y seguir. Decide qué fragmento consumir cuando falla una forma esperada:

- Para identificador con cierre, reconoce primero la forma completa y valida longitud en la acción. Si supera 32, reporta todo ese identificador y continúa.
- Para enteros como `p0i` o `n01i`, una regla más amplia para signo p/n, dígitos e i puede reportar el error completo. La válida debe ir antes para ganar los empates.
- Para cadena sin cierre, recupera al llegar al salto de línea o EOF; para contenido inválido, descarta hasta cierre, salto o EOF. Guarda la línea inicial si la acción también consume un salto.
- Para comentarios sin cierre, EOF termina el análisis después del diagnóstico.
- Para otros caracteres, consume uno y reporta. No descartes indiscriminadamente hasta espacio: podrías perder `:=p1i` después de un identificador.

Tema 2, p. 7, permite discutir diferentes políticas: `2.2.3` puede reconocerse como dos reales o como un fragmento erróneo si añades validación más estricta. Con nuestros patrones válidos, se divide en `2.2` y `.3`. Igualmente, `1.2e` puede producir el real `1.2` y un error en `e`; si quieres un solo diagnóstico para el real incompleto, debes diseñar esa regla adicional.

No agregues una regla general de “palabra inválida” sin comprobar fronteras. El enunciado admite el inicio de otro componente como delimitador. Y donde toda la concatenación sea un lexema válido, como `I_a_II_b_I`, la coincidencia más larga será un solo identificador.

### Pruebas dirigidas para tus correcciones

Estos son resultados esperados para **lexemas completos**; después hay que probar cómo el analizador divide una entrada y se recupera.

| Familia | Debe aceptar | Debe rechazar como un solo lexema |
|---|---|---|
| Identificador | I_a_I, I_valor_mayor_I, cuerpo de 28 caracteres | Cuerpo de 29; I__I con tu mínimo 1 |
| Asignación | :=, :+, :-, :*, :/, :% | :q |
| Relacional | +q, -q, +iq, -iq, :i, d/i | +iiq, dq |
| Aritmético | &+, &-, &*, &/, &&*, &%&, &*& | %&, *&, && |
| Especial | @>, $$, #?, ::=, ?=, %~, + | $ |
| Entero | 0i, p10i, n205i | p0i, n0i, p01i, 25i |
| Real | 1.0, .24, -2.2, 32e-3, -4.4E2, 1e10, 1e0 | ., 1., 32, 1e, 1e-, +1.2 |
| Cadena | <>, <hola mundo>, <@n @f @d @t> | Texto sin cierre; salto/tabulador interno |

Prueba después una entrada como `p0i int`: debe informar el entero inválido y todavía generar `(0,10)` para `int`. Eso comprueba recuperación, no sólo coincidencia de patrones.

### Por dónde continuar sin intentar escribir todo a la vez

Empieza por los bloques Token, EntradaSimbolo y EntradaLiteral: traduce sus campos a estructuras de C. Después escribe `main` hasta abrir y cerrar un archivo vacío. A continuación conecta una sola reservada con `agregar_token` e impresión. Cuando ese recorrido pequeño funcione, añade búsqueda e inserción de identificadores, literales, demás clases y recuperación.

La estructura comentada no es todavía un analizador funcional. Los pasos indicados son una guía para que construyas y pruebes cada pieza.

### Qué se comprobó en esta revisión

Se verificaron 97 casos de lexemas completos con las ocho expresiones corregidas (identificadores, cuatro familias de operadores/símbolos, enteros, reales y cadenas), usando patrones compilados por Flex en archivos temporales fuera del proyecto. También se verificó que Flex acepta el archivo comentado y que el C que genera pasa una comprobación de sintaxis. Eso valida las referencias y la estructura del cuaderno; todavía no prueba un analizador completo, sus tablas, la conversión numérica ni la recuperación, porque esas acciones quedan por implementar.
