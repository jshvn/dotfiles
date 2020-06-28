## 👨🏻‍💻 Josh's dotfiles

This repository is meant to act as a working copy of my computer configuration, SSH settings, macOS settings, general applications, and more for my personal and development machines. 

These dotfiles have only been tested on macOS, but in theory should also work on Linux systems.


## 🖥 How to install or update

When setting up a new machine, or wanting to update an existing machine after updates or major changes, run the following commands.

Brew will give errors when packages are already installed - these can be safely ignored.

You may need to run the install file more than once as sometimes things can get stuck.

```
    $ git clone https://github.com/jshvn/dotfiles.git
    $ cd dotfiles/install
    $ chmod +x install.sh
    $ ./install.sh
```

### 🛠 Install details

The install process is multi-step and will likely take quite a bit of time to complete depending on your internet connection and machine capability. In general it is recommended to connect via ethernet and let this run until completion.

**Install process**


* **`install/install.sh`**
    * script will identify dotfiles repo location
    * script will check which system it is being run on
    * macos:
        * script will source `install/macos/link.sh` which sets up symlinks for custom aliases and functions here
        * script will install [oh my zsh](https://github.com/ohmyzsh/ohmyzsh)
        * script will source `install/macos/macos.sh` which installs [homebrew](https://brew.sh/) and macOS specifics like Xcode
        * script will source `install/macos/defaults.sh` which sets a bunch of macOS system preferences
    * linux:
        * script will install `curl`, `build-essential`, and the `zsh` shell since Ubuntu's default is `bash`
        * script will set `zsh` as default shell
        * script will source `install/linux/link.sh` which sets up symlinks for custom aliases and functions here
        * script will install [oh my zsh](https://github.com/ohmyzsh/ohmyzsh)
        * script will source `install/linux/linux.sh` which installs [homebrew](https://brew.sh/) and macOS specifics like Xcode


**Platform specific install process**

* `install/macos/macos.sh`
    * script will install [homebrew](https://brew.sh/)
    * homebrew will install utilities, packages, and applications acording to what is defined in `install/common/Brewfile`
    * homebrew will install utilities, packages, and applications acording to what is defined in `install/macos/Brewfile`
    * script will install XCode developer tools and command line application
* `install/linux/linux.sh`
    * script will install [homebrew](https://brew.sh/) and add it to the current shell environment
    * homebrew will install utilities, packages, and applications acording to what is defined in `install/common/Brewfile`
    * homebrew will install utilities, packages, and applications acording to what is defined in `install/linux/Brewfile`

**Update process**

If you just need to update what is exposed to `zsh` in the `zsh` directory then a simple `$ reload` command should suffice.

If you need to download additional binaries that have been added to the dotfiles then you will want to run through the install process again. That process is detailed above.

You may need to do this multiple times or resolve any cross-platform issues that arise.


### 🦪 ZSH details

The symlinks that are created during the install process will link to the zsh files located here in this repository. They effectively replace whatever files were already there on the system, which allow me to have the same environment and utilities available on all my machines without much effort.

These will be sourced every time a new shell is spawned. They can also be resourced on the fly with a `$ reload` command.

ZSH scripts:

* `zsh/.zshrc`
    * this is the main shell configuration script that runs every time terminal starts
    * this will set the ZSH theme and choose which plugins to import
    * this will source oh-my-zsh
    * this will source the `common`, `macos`, or `linux` custom aliases
    * this will source the `common`, `macos`, or `linux` custom functions
    * this will source the `zsh/theme.zsh` custom theme overrides
    * this will source any helper scripts that exist in the `zsh/scripts/` subdirectory
    * this will also configure the miniconda environment for macOS devices
* `zsh/theme.zsh`
    * this will define any theme overrides for all platforms
    * this will set `$LS_COLOR` / `$LSCOLOR` overrides
    * this will set `$PROMPT` overrides
* `*/aliases.zsh`
    * this will define all the useful custom aliases for injection into shell environment
    * aliases should strive to be `common` when possible, but there exist platform specific subdirectories
* `*/functions.zsh`
    * this will define all the useful custom functions for injection into shell environment
    * functions should strive to be `common` when possible, but there exist platform specific subdirectories


## 📘 Notes

If you change the location of this repo on the filesystem, you will need to re-run the appropriate `install/*/link.sh` script again because the symlinks to the files within this repo will be broken.

The scripts are intelligent enough to work regardless of where the git repo is located on the system. It will automatically pick up the location and make the appropriate symlinks when the `install/install.sh` script is run.

You need not worry about packages being reinstalled: if the packages are already installed, brew will identify that and skip them. Some of the casks and App Store packages will give an error indicating they are already installed - this is expected and can be safely ignored.

## 📚 References

Some useful places to grab dotfile functionality:

- https://github.com/mathiasbynens/dotfiles
- https://github.com/jakejarvis/dotfiles
- https://github.com/holman/dotfiles
