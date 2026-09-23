.po 0.75i
.ll 7i
.de TL
.sp 0.35i
.ps 18
.vs 22
.ft B
.ce 1
..
.de AU
.ps 12
.vs 15
.ft R
.ce 1
..
.de AI
.ps 10
.vs 12
.ft I
.ce 1
.sp 0.25i
..
.de PP
.br
.in 0
.ti 0.25i
.ft R
.ps 10
.vs 12
.sp 0.6v
..
.de NH
.br
.in 0
.ft B
.ie \\$1=1 .ps 14
.el .ps 11
.vs 16
.sp 1v
.ne 3
..
.de IP
.br
.ne 2
.ft R
.ps 10
.vs 12
.in 0.3i
.ti -0.3i
\\$1\h'0.12i'\c
..
.ds HF 3 3 3 3 3 3 3
.nr PS 10
.nr VS 12
.nr HM 0.7i
.nr FM 0.7i
.TL
Guía de trabajo: analizador léxico con Flex
.AU
Cuaderno de diseño y programación socrática
.AI
Compiladores, semestre 2027-1
.PP
Esta guía transforma el enunciado en una ruta de trabajo. No es un documento listo para entregar ni contiene las expresiones regulares o el código resueltos. Su propósito es ayudarte a tomar cada decisión, escribirla con tus palabras y comprobarla antes de avanzar.
.NH 1
Qué debe existir al final
.PP
El producto tiene dos partes: un único programa fuente definitivo de Flex con el código C necesario, y un documento de entrega con descripción del problema, expresiones regulares, planificación, diseño, pruebas, instrucciones y conclusiones.
.PP
Convierte el enunciado en una lista verificable:
.IP \(bu 3
Reconocer las nueve clases, numeradas de 0 a 8.
.IP \(bu 3
Conservar los valores exactos de cada catálogo.
.IP \(bu 3
Registrar identificadores sin duplicarlos.
.IP \(bu 3
Registrar cada aparición de una cadena o real, incluso si se repite.
.IP \(bu 3
Convertir una constante entera a su valor numérico.
.IP \(bu 3
Ignorar comentarios de línea y de bloque.
.IP \(bu 3
Informar errores con número de línea y continuar.
.IP \(bu 3
Aceptar por línea de comandos el archivo fuente.
.IP \(bu 3
Mostrar las tres tablas y la secuencia de tokens al terminar.
.PP
Pregunta de control: ¿cada requisito puede señalarse en una función, regla o prueba concreta?
.NH 1
Decisiones que conviene aclarar primero
.PP
Anota tu interpretación y, si es posible, confírmala con la profesora antes de fijar las expresiones regulares.
.IP \(bu 3
El primer ejemplo de identificador parece tener un espacio antes de _I. ¿Es un error tipográfico? ¿Sería compatible con la descripción formal?
.IP \(bu 3
Los enteros usan n y p, pero los reales de ejemplo usan - y no muestran +. ¿Qué signos exactos aceptarás para cada clase?
.IP \(bu 3
¿La notación científica exige parte decimal o también permite 32e-3, como indica el ejemplo?
.IP \(bu 3
Dentro de <...>, ¿un > sin mecanismo de escape siempre termina la cadena?
.IP \(bu 3
¿Qué significa que @n, @f, @d y @t pueden referenciar valores: secuencias internas, componentes separados o sustituciones?
.IP \(bu 3
¿Qué debe informarse ante un comentario o una cadena sin cierre?
.IP \(bu 3
Si un prefijo parece iniciar un token válido y después falla, ¿qué fragmento se reportará como un solo error?
.NH 1
Construcción de expresiones regulares
.PP
Trabaja una clase a la vez. Para cada clase llena cuatro columnas: lenguaje en palabras, bloques pequeños, expresión completa y fronteras o casos inválidos.
.NH 2
Clase 0: palabras reservadas
.PP
Hay 17 palabras y sus valores 0 a 16 son inamovibles. ¿Conviene una regla por palabra o una regla conjunta con búsqueda? ¿Cómo garantizas que el valor coincide con la posición dada? ¿Se distinguen mayúsculas y minúsculas?
.NH 2
Clase 1: identificadores
.PP
Descompón la forma en prefijo, cuerpo y sufijo. ¿Puede el cuerpo estar vacío? ¿El guion bajo pertenece también al cuerpo? ¿Cómo impones 32 caracteres totales? ¿Cómo reportas completa una forma de 33 caracteres? Calcula primero el máximo del cuerpo.
.NH 2
Clases 2 a 5: operadores y símbolos
.PP
Copia el orden exacto de los catálogos y marca todo lexema que sea prefijo de otro. ¿Qué elige Flex ante dos coincidencias que empiezan juntas? Si tienen igual longitud, ¿qué papel juega el orden? ¿Cómo pruebas los lexemas solapados? ¿Una función común puede obtener el índice de cualquier catálogo?
.NH 2
Clase 6: constantes enteras
.PP
Separa cero, positivo distinto de cero y negativo. ¿Cómo impides formas con signo de cero? ¿Aceptarás ceros iniciales? ¿Cómo conviertes y detectas desbordamiento? ¿Qué partes del lexema deben excluirse o interpretarse durante la conversión?
.NH 2
Clase 7: constantes reales
.PP
Construye por separado forma decimal, exponente y signo. ¿Cuántos dígitos exige cada lado del punto? ¿Qué partes son opcionales en 32e-3? ¿Aceptas e y E, y cuáles signos? Si el dato se almacena como cadena, ¿es necesaria una conversión numérica?
.NH 2
Clase 8: constantes cadena
.PP
¿Cómo representas ASCII 32 a 126 sin consumir el delimitador final? ¿Es válida <>? ¿Se permiten saltos de línea? ¿Las secuencias con @ requieren trato especial? Decide si la tabla guarda delimitadores o sólo contenido y explica por qué.
.NH 2
Espacios, comentarios y errores
.PP
Diseña el descarte de uno o más espacios, tabuladores o saltos. Compara para comentarios de bloque una sola expresión con un estado exclusivo de Flex: ¿cuál detecta mejor el fin de archivo sin cierre y mantiene la línea? La estrategia final de error debe consumir siempre algo. ¿Por qué eso garantiza progreso?
.NH 1
Diseño del programa en C
.NH 2
Token
.PP
Debe guardar clase y valor. ¿Qué tipos corresponden? ¿Cómo crecerá una secuencia de longitud desconocida? ¿Qué función agregará un token sin repetir lógica en nueve acciones?
.NH 2
Tabla de símbolos
.PP
Cada entrada contiene posición, nombre y tipo inicialmente -1. ¿La posición se almacena o se deduce del índice? ¿Copiarás el nombre o conservarás yytext? Investiga qué ocurre con yytext tras la siguiente coincidencia. Justifica búsqueda lineal u otra técnica. Diseña una sola operación buscar-o-insertar que siempre devuelva la posición.
.NH 2
Tablas de literales
.PP
Cada entrada contiene posición y dato como cadena; hay una tabla para reales y otra para cadenas. ¿Por qué insertar no debe buscar duplicados? ¿Pueden compartir tipo y función? ¿Quién reserva, copia y libera cada dato?
.NH 2
Catálogos fijos
.PP
Una representación debe preservar el orden dado y convertir lexema en índice. ¿Usarás arreglos de cadenas? ¿Una búsqueda sirve a los cinco catálogos? ¿Cómo evitas escribir una longitud que pueda desactualizarse?
.NH 2
Memoria dinámica
.PP
Para cada arreglo define tamaño usado y capacidad. ¿Cuándo debe crecer? ¿Qué política evita reservar en cada inserción? ¿Cómo evita un apuntador temporal perder el bloque original al fallar una redimensión? Enumera todo lo que debe liberarse al final y en salidas por error.
.NH 1
Flujo completo
.IP 1. 4
Validar la cantidad de argumentos.
.IP 2. 4
Abrir el archivo indicado y comprobar el resultado.
.IP 3. 4
Asignar el flujo de entrada de Flex.
.IP 4. 4
Inicializar estructuras.
.IP 5. 4
Analizar hasta fin de archivo y acumular resultados.
.IP 6. 4
Cerrar el archivo.
.IP 7. 4
Mostrar símbolos, literales y tokens.
.IP 8. 4
Liberar toda la memoria propia.
.IP 9. 4
Devolver un estado que distinga éxito y distintos fallos.
.PP
Si ocurre un error léxico recuperable, ¿debe interrumpirse alguno de esos pasos?
.NH 1
Orden de implementación recomendado
.IP 1. 4
Crear el esqueleto y comprobar entrada por línea de comandos.
.IP 2. 4
Activar y comprobar conteo de líneas.
.IP 3. 4
Ignorar delimitadores y reconocer errores carácter por carácter.
.IP 4. 4
Definir tipos y operaciones de almacenamiento.
.IP 5. 4
Implementar catálogos fijos y búsquedas.
.IP 6. 4
Añadir clases 0 y 2 a 5, verificando valores exactos.
.IP 7. 4
Añadir identificadores con buscar-o-insertar.
.IP 8. 4
Añadir enteros y comprobar conversión y cero.
.IP 9. 4
Añadir reales y cadenas con inserción incondicional.
.IP 10. 4
Añadir comentarios, incluido fin de archivo inesperado.
.IP 11. 4
Imprimir resultados y liberar memoria.
.IP 12. 4
Ejecutar integración y revisar memoria con herramientas apropiadas.
.NH 1
Matriz mínima de pruebas
.PP
Escribe antes el resultado esperado: tokens, posiciones, errores y línea.
.TS
tab(|) box;
lb | lb
l | l.
Familia|Casos que debes preparar
Reservadas|Las 17; mayúscula; varias consecutivas
Identificador|Cuerpo mínimo; longitud 32 y 33; repetido; carácter prohibido
Asignación|Los 6; consecutivos; prefijos incompletos
Relacionales|Los 6; prefijos parecidos; secuencia inválida
Aritméticos|Los 7; lexemas solapados
Especiales|Los 7; combinaciones sin espacios
Enteros|Cero; positivo; negativo; cero con signo; sin i; enorme
Reales|Ejemplos; exponentes; signos; punto solo; exponente incompleto
Cadenas|Vacía; espacios; @; límite ASCII; sin cierre; salto
Comentarios|Línea; bloque; varias líneas; marcadores; sin cierre
Integración|Sin espacios; errores entre tokens; archivo vacío
.TE
.PP
Comprueba además: un identificador repetido mantiene una posición y una entrada; un literal real o cadena repetido crea dos; después de un error se reconoce el token válido siguiente; las líneas siguen correctas tras comentarios y rechazos.
.NH 1
Documento de entrega
.IP 1. 4
Descripción del problema con tus palabras, restricciones, expresiones regulares y casos frontera.
.IP 2. 4
Propuesta y fases: actividades, responsables y calendario; estructuras, memoria, búsqueda e inserción; casos y resultados de prueba.
.IP 3. 4
Ejecución: requisitos, generación con Flex, compilación, invocación y salida.
.IP 4. 4
Conclusión por participante: decisiones, dificultades, evidencia de aprendizaje y mejoras.
.PP
La fecha indicada es el 29 de septiembre de 2026. Reserva tiempo para probar el paquete final desde una carpeta limpia.
.NH 1
Forma de trabajar con el archivo guía
.PP
Usa analizador.l como cuaderno. Contesta sus comentarios, escribe la parte mínima correspondiente, compila, ejecuta casos pequeños y conserva las pruebas que descubran errores. Sólo entonces avanza. Cuando pidas ayuda, muestra el bloque, el comando, la entrada mínima y el resultado: así podremos razonar sobre una decisión concreta sin sustituir tu trabajo.
