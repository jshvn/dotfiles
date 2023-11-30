## 👨🏻‍💻 Josh's dotfiles

This repository is meant to act as a working copy of my computer configuration, SSH settings, macOS settings, general applications, and more for my personal and development machines. 

These dotfiles have been tested on:

* macOS 14.0 Sonoma
* Ubuntu 22.04


## 🖥 How to install or update

When setting up a new machine, or wanting to update an existing machine after updates or major changes, run the following commands.

**Fresh install:**
```
    $ git clone https://github.com/jshvn/dotfiles.git
    $ cd dotfiles
    $ ./bootstrap.sh
```

**Update:**
```
    $ update
```

### 🛠 Install details

The install process is multi-step and will likely take quite a bit of time to complete depending on your internet connection and machine capability. In general it is recommended to connect via ethernet and let this run until completion.

There are almost always bugs when upgrading to a new OS version. The install process is set such that when an error occurs, the process will halt and you will need to diagnose and fix.

**Boostrap:**

This launcher will install and configure the complete dotfiles. 

**`$ bootstrap.sh`**

**Install process:**

Script sources in the following order:

1. `boostrap.sh` sources `install/install.sh`
2. `install/install.sh` sources `install/linux/linux.sh` or `install/macos/macos.sh` depending on system
3. System install script runs `install/linux/link.sh` or `install/macos/link.sh` to setup symlinks for this repo

On macOS, `install/macos/defaults.sh` is also sourced to set some default preferences on the machine.

**ARM vs Intel**

On ARM Macs Homebrew installs packages to:
    `/opt/homebrew/bin/`

On Intel Macs Homebrew installs packages to:
    `/usr/local/bin/`

Some aliases and other functions may need to be updated or checked to ensure compatibility.

### 🔭 Update details

If you simply need to reload what is already exposed to `zsh` in your local filesystem then a simple `$ reload` command is sufficient.

If you need to update the dotfiles from origin and potentially install new applications, see the update details above.


### 🦪 ZSH details

The symlinks that are created during the install process for the dotfiles will link to the zsh files located here in this repository. They effectively replace whatever files were already there on the system, which allow me to have the same environment and utilities available on all my machines without much effort.

These will be sourced every time a new shell is spawned. They can also be resourced on the fly with a `$ reload` command.

ZSH scripts:

* **`zsh/.zshrc`**
    * this is the main shell configuration script that runs every time terminal starts
    * this will set the ZSH theme and choose which plugins to import
    * this will source oh-my-zsh
    * this will source the `common`, `macos`, or `linux` custom aliases
    * this will source the `common`, `macos`, or `linux` custom functions
    * this will source the `zsh/theme.zsh` custom theme overrides
    * this will source any helper scripts that exist in the `zsh/scripts/` subdirectory
    * this will also initialize the miniconda environment for current shell for macOS devices
* **`zsh/theme.zsh`**
    * this will define any theme overrides for all platforms
    * this will set `$LS_COLOR` / `$LSCOLOR` overrides
    * this will set `$PROMPT` overrides
* **`zsh/aliases.zsh`**
    * this will define all the useful custom aliases for injection into shell environment
* **`zsh/functions.zsh`**
    * this will define all the useful custom functions for injection into shell environment


### 🤓 Cheat details

Perhaps one of the more useful aspects of these dotfiles is the included `$ cheat` infrastructure. 

There is a custom script `cheat.zsh` that gets sourced into ZSH when the dotfiles are installed that allows you to read beautified markdown files from within the terminal. I'm using this to store information about commands I use frequently enough to need to know how to use them correctly, but not frequently enough that I always remember exactly what the command syntax is. 

I have added a few really common ones I use in there so far, but this can be easily expanded by updating both `zsh/cheat/cheat.zsh` and `zsh/cheat/cheat.md` with the command to access the cheatfile and the appropriate cheatfile documentation.


## 📘 Notes

If you change the location of this repo on the filesystem, you will need to re-run the `bootstrap.sh` or `link.sh` script again because the symlinks to the files within this repo will be broken.

The scripts are intelligent enough to work regardless of where the git repo is located on the system. It will automatically pick up the location and make the appropriate symlinks when the `install/install.sh` script is run.

You need not worry about packages being reinstalled: if the packages are already installed, brew will identify that and skip them.

## 📚 License and references

There are a ton of folks with better dotfiles than these that were the inspiration for this project. The links for those are below.

I'm packaging up what is here under the MIT license. Feel free to pick and pull whatever is useful to you. Happy hacking!

- https://github.com/mathiasbynens/dotfiles
- https://github.com/jakejarvis/dotfiles
- https://github.com/holman/dotfiles
- https://github.com/sirugh/dotfiles/
