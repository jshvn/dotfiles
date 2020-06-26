# dotfiles

This repo is a backup of the environment configuration, SSH settings, macOS settings, general applications, and more for my personal machines.

This is meant to be run on macOS only.


## Usage

When setting up a new machine, or wanting to update an existing machine after updates or major changes, run the following commands.

Brew will give errors when packages are already installed - these can be safely ignored.

You may need to run the install file more than once as sometimes things can get stuck.

```
git clone https://github.com/jshvn/dotfiles.git
cd dotfiles
./install.sh
```

### Install details

The install process is multi-step and will likely take quite a bit of time to complete depending on your internet connection and machine capability. In general it is recommended to connect via ethernet and let this run until completion.

The install script generally follows this logic:

* Execute `install.sh`
    * script will identify dotfiles repo location
    * script will symlink over ~/.dotfiles to repo location (this includes installing all custom `zsh/aliases.zsh` and `zsh/functions.zsh`)
    * script will load any custom functions available in `zsh/scripts`
    * script will install [oh my zsh](https://github.com/ohmyzsh/ohmyzsh)
    * script will start `macos/macos.sh`
* Execute `macos/macos.sh`
    * script will install [homebrew](https://brew.sh/)
    * homebrew will install utilities acording to what is defined in `Brewfile`
    * homebrew will install packages according to what is defined in `Brewfile`
    * homebrew will install applications from App Store according to what is defined in `Brewfile`
* Install Xcode and Xcode Command Line tools
* Execute `macos/defaults.sh`
    * script will set systemwide preferences applicable to any macOS install



### Notes

If you chnage the location of this repo on the filesystem, you will need to re-run the `install.sh` script again because the symlinks to the files within this repo will be broken.

You need not worry about packages being reinstalled: if the packages are already installed, brew will identify that and skip them. Some of the casks and App Store packages will give an error indicating they are already installed - this is expected and can be safely ignored.

## References

Some useful places to grab dotfile functionality:

- https://github.com/mathiasbynens/dotfiles
- https://github.com/jakejarvis/dotfiles

