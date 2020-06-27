## 👨🏻‍💻 Josh's dotfiles

This repository is meant to act as a working copy of my computer configuration, SSH settings, macOS settings, general applications, and more for my personal and development machines. 

These dotfiles have only been tested on macOS, but in theory should also work on Linux systems.


## 🖥 How to install and use

When setting up a new machine, or wanting to update an existing machine after updates or major changes, run the following commands.

Brew will give errors when packages are already installed - these can be safely ignored.

You may need to run the install file more than once as sometimes things can get stuck.

```
    $ git clone https://github.com/jshvn/dotfiles.git
    $ cd dotfiles
    $ chmod +x install.sh
    $ ./install.sh
```

### 🛠 Install details

The install process is multi-step and will likely take quite a bit of time to complete depending on your internet connection and machine capability. In general it is recommended to connect via ethernet and let this run until completion.

Installation process:

* `install.sh`
    * script will identify dotfiles repo location
    * script will symlink over ~/.dotfiles to repo location (this includes installing all custom `zsh/aliases.zsh` and `zsh/functions.zsh`)
    * script will load any custom functions available in `zsh/scripts`
    * script will install [oh my zsh](https://github.com/ohmyzsh/ohmyzsh)
    * script will source `macos/macos.sh`
    * script will source `macos/defaults.sh`
* `macos/macos.sh`
    * script will install [homebrew](https://brew.sh/)
    * homebrew will install utilities acording to what is defined in `macos/apps/Brewfile`
    * homebrew will install packages according to what is defined in `macos/apps/Brewfile`
    * homebrew will install applications from Apple App Store according to what is defined in `macos/apps/Brewfile`
    * install XCode developer tools and command line application
* `macos/defaults.sh`
    * script will set systemwide preferences applicable to any macOS install

### 🦪 ZSH details

The symlinks that are created during the install process will link to the zsh files located here in this repository. They effectively replace whatever files were already there on the system, which allow me to have the same environment and utilities available on all my machines without much effort.

These will be sourced every time a new shell is spawned. They can also be resourced on the fly with a `$ reload` command.

ZSH scripts:

* `zsh/.zshrc`
    * this is the main shell configuration script that runs every time terminal starts
    * this will set the ZSH theme and choose which plugins to import
    * this will source oh-my-zsh
    * this will source the `zsh/aliases.zsh` custom aliases
    * this will source the `zsh/functions.zsh` custom functions
    * this will source the `zsh/theme.zsh` custom theme overrides
    * this will source any helper scripts that exist in the `zsh/scripts/` subdirectory
    * this will also configure the miniconda environment
* `zsh/aliases.zsh`
    * this will define all the useful custom aliases for injection into shell environment
* `zsh/functions.zsh`
    * this will define all the useful custom functions for injection into shell environment
* `zsh/theme.zsh`
    * this will define any theme overrides
    * this will set $LS_COLOR / $LSCOLOR overrides
    * this will set $PROMPT overrides

## 📘 Notes

If you chnage the location of this repo on the filesystem, you will need to re-run the `install.sh` script again because the symlinks to the files within this repo will be broken.

The scripts are intelligent enough to work regardless of where the git repo is located on the system. It will automatically pick up the location and make the appropriate symlinks when the `install.sh` script is run.

You need not worry about packages being reinstalled: if the packages are already installed, brew will identify that and skip them. Some of the casks and App Store packages will give an error indicating they are already installed - this is expected and can be safely ignored.

## 📚 References

Some useful places to grab dotfile functionality:

- https://github.com/mathiasbynens/dotfiles
- https://github.com/jakejarvis/dotfiles

