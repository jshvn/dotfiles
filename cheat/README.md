## Cheat directory

These subdirectories are meant to support the `$ cheat` shell command bundled in these dotfiles. They contain "cheatsheet" information for various utilities that are at a higher level than man pages for commonly used tools.

The primary format for these is markdown as can be seen in the `md` subdirectory, but in some cases the original `pdf` is also bundled where available. 

---
 
 `glow_style.json`

> For pretty printing in the terminal, a package called `glow` is used to format and apply color to these markdown files. The repo for this package is located [here](https://github.com/charmbracelet/glow).

> Glow is bundled with default styles, but I've customed the output to my liking. The included `glow_style.json` has the customizations I've made and is provided to `glow` each time it is run as part of the cheat system.