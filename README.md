## 👨🏻‍💻 Josh's dotfiles

This repository is a working copy of my machine configuration, settings, and software. 

##  How to install or update

**Fresh macOS install:**
```
    $ git clone https://github.com/jshvn/dotfiles.git
    $ cd dotfiles
    $ zsh install.sh
```

**Update software:**
```
    $ update
```

## ⚙️ Technical details

### 🛠 Installation

Installation generally sets up several aspects of the machine for use:

1. [git](git/) 
2. [system defaults and links](install/)
3. [ssh configs](ssh/configs/)
4. [applications](install/Brewfile.rb)
5. [zsh](zsh/)

## 📘 Notes

If you change the location of this repo on the filesystem, you will need to re-run the `install.sh` or `links.sh` script again because the symlinks to the files within this repo will be broken.

## ☁️ Cloudflare Warp

Cloudflare WARP is used to enable connectivity between machines on the network `100.96.0.0/12`. The following guides were used:

- Overall: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-to-warp/
- Split Tunnel configuration: https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/configure-warp/route-traffic/split-tunnels/

## 📚 License and references

There are a ton of folks with better dotfiles than these that were the inspiration for this project. The links for those are below.

I'm packaging up what is here under the MIT license. Feel free to pick and pull whatever is useful to you. Happy hacking!

- https://github.com/mathiasbynens/dotfiles
- https://github.com/jakejarvis/dotfiles
- https://github.com/holman/dotfiles
- https://github.com/sirugh/dotfiles/
