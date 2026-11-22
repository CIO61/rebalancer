# Rebalancer
Esta extensión se puede usar para configurar una amplia variedad de aspectos del equilibrio del juego.

## Uso
La extensión solo toma un archivo como entrada, que debe ser un archivo JSON conforme al esquema definido en la extensión. Usar un editor de texto compatible con esquemas JSON puede ayudarte a crear tus propios archivos de equilibrio.

## Colocación de edificios y posturas
Dos secciones del archivo de equilibrio modifican valores concretos en el código del juego:

* `building_placement`: el alcance de construcción del castillo para cada tamaño de mapa (a qué distancia de tu fortaleza pueden construirse partes del castillo en escaramuza y multijugador) y lo cerca que pueden estar las unidades enemigas al colocar un almacén, un granero o una armería, una tienda de asedio o una muralla de la IA.
* `stances`: a qué distancia buscan enemigos las unidades en postura agresiva y defensiva, cuántas de ellas persiguen al mismo enemigo y a qué distancia buscan las unidades cuerpo a cuerpo en postura agresiva un edificio al que atacar.

Cada clave es opcional. Una clave omitida conserva el valor original del juego y Rebalancer no la toca. Cada valor se localiza a partir del código que lo rodea en Stronghold Crusader y Crusader Extreme y solo se escribe si aún conserva el valor propio del juego. Si un valor no se puede encontrar o ya lo ha modificado otro módulo, ese ajuste se omite y el registro indica el motivo. El esquema enumera cada clave junto con su rango permitido y el valor del juego.
