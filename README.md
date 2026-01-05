# ha-json-schema

script to extract the JSON schemas from [vscode-home-assistant](https://github.com/keesschollaart81/vscode-home-assistant),
format them, pull them into the repo's `schemas/` folder, and publish them to GitHub Pages for use with
[yaml-language-server](https://github.com/redhat-developer/yaml-language-server).


## Acknowledgements

inspired by [johnhamelink's hass-json-schema](https://git.sr.ht/~johnhamelink/hass-json-schema/),
which does the same thing, but as of this writing is not actually *usable* due to sourcehut's aggressive 
anti-bot protections blocking `yaml-language-server`'s requests for the schema files.
