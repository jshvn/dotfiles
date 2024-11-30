###############################
#  Install helper             #
###############################

def brew_install_or_upgrade(formula)
    if system("brew list --versions #{formula} >/dev/null")
        system("brew upgrade #{formula}")
    else
        system("brew install #{formula}")
    end
end

###############################
#  Utilities                  #
###############################

# we want ZSH as our default shell on all environments
# and not to use system as to keep it updated with latest
brew_install_or_upgrade("zsh")

# wget for pulling web data
brew_install_or_upgrade("wget")

# eza as ls replacement
brew_install_or_upgrade("eza")

# install git since platform git is often old
brew_install_or_upgrade("git")

# glow for markdown rendering in the terminal 
# https://github.com/charmbracelet/glow
brew_install_or_upgrade("glow")

# highlight for syntax highlighting in the terminal
# http://www.andre-simon.de/doku/highlight/en/highlight.php
# https://gitlab.com/saalen/highlight
brew_install_or_upgrade("highlight")

# install highlighting for several commands like whois, ping, etc
# https://github.com/garabik/grc
brew_install_or_upgrade("grc")

# perl-like regular expressions, used in some aliases
brew_install_or_upgrade("pcre")

# htop is a better top
brew_install_or_upgrade("htop")

# duf is a better df
brew_install_or_upgrade("duf")

# 7zip for file compression/decompression
brew_install_or_upgrade("p7zip")

# domain name lookup and information
brew_install_or_upgrade("whois")

# name server record lookup and information
brew_install_or_upgrade("doggo")

# bat is a better cat
brew_install_or_upgrade("bat")

# hugo is useful for static site generation & deployment
brew_install_or_upgrade("hugo")

# ncdu is a better tool for showing directory sizes
brew_install_or_upgrade("ncdu")

# tldr is like man, but better
brew_install_or_upgrade("tldr")

# trippy is like traceroute, but better
brew_install_or_upgrade("trippy")

# fd is a find replacement
brew_install_or_upgrade("fd")

# cloudflared client
brew_install_or_upgrade("cloudflared")

# fastfetch used for printing system information
# neofetch was used previously, but it has been archived as of April 26, 2024
brew_install_or_upgrade("fastfetch")

# onefetch used for printing git repo information
brew_install_or_upgrade("onefetch")

# bottom is like htop
brew_install_or_upgrade("bottom")