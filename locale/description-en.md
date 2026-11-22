# Rebalancer
This extension can be used to configure a wide variety of aspects in game balance. 

## Usage
The extension only takes a file as its input, which is expected to be a JSON file obeying the schema defined under the extension. Using a text editor with JSON schema supports can help creating your own balance files.

## Building placement and stances
Two sections of the balance file change single values in the game's code:

* `building_placement`: the castle build range for each map size (how far from your keep castle parts may be built in skirmish and multiplayer), and how close enemy units may be when a stockpile, granary or armoury, a siege tent, or an AI wall is placed.
* `stances`: how far units in aggressive and defensive stance look for enemies, how many of them go after the same enemy, and how far aggressive melee units look for a building to attack.

Every key is optional. A key that is left out keeps the game's own value, and Rebalancer does not touch it. Each value is found by the code around it in Stronghold Crusader and Crusader Extreme and written only if it still holds the game's own value. If a value cannot be found, or another module has already changed it, that setting is skipped and the log says why. The schema lists every key with its allowed range and the game's value.
