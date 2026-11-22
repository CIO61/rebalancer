# Rebalancer
Cette extension permet de configurer de nombreux aspects de l'équilibrage du jeu.

## Utilisation
L'extension ne prend qu'un fichier en entrée, qui doit être un fichier JSON conforme au schéma défini dans l'extension. Utiliser un éditeur de texte prenant en charge les schémas JSON peut vous aider à créer vos propres fichiers d'équilibrage.

## Placement des bâtiments et postures
Deux sections du fichier d'équilibrage modifient des valeurs précises dans le code du jeu :

* `building_placement` : la portée de construction du château pour chaque taille de carte (à quelle distance de votre donjon les éléments du château peuvent être construits en escarmouche et en multijoueur), ainsi que la proximité autorisée des unités ennemies lors du placement d'une réserve, d'un grenier ou d'une armurerie, d'une tente de siège ou d'un mur de l'IA.
* `stances` : la distance à laquelle les unités en posture agressive ou défensive recherchent des ennemis, le nombre d'unités qui poursuivent le même ennemi et la distance à laquelle les unités de mêlée agressives recherchent un bâtiment à attaquer.

Chaque clé est facultative. Une clé omise conserve la valeur d'origine du jeu et Rebalancer n'y touche pas. Chaque valeur est localisée grâce au code qui l'entoure dans Stronghold Crusader et Crusader Extreme, et n'est écrite que si elle contient encore la valeur d'origine du jeu. Si une valeur est introuvable ou a déjà été modifiée par un autre module, ce paramètre est ignoré et le journal indique pourquoi. Le schéma répertorie chaque clé avec sa plage autorisée et la valeur du jeu.
