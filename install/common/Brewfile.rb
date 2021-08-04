###############################
#  Taps                       #
###############################

tap "homebrew/homebrew-cask"
tap "homebrew/cask-versions"

###############################
#  Binaries                   #
###############################

# wget for pulling web data
brew "wget" 

# glow for markdown rendering in the terminal 
# https://github.com/charmbracelet/glow
brew "glow" 

# highlight for syntax highlighting in the terminal
# http://www.andre-simon.de/doku/highlight/en/highlight.php
# https://gitlab.com/saalen/highlight
brew "highlight" 

# install highlighting for several commands like whois, ping, etc
# https://github.com/garabik/grc
brew "grc"

# perl-like regular expressions, used in some aliases
brew "pcre" 

# htop is a better top
brew "htop"

# unrar and 7zip for file compression/decompression
# 2021-08-04: unrar has been removed from homebrew due to licensing issues
#brew "unrar"
brew "p7zip"

# domain name lookup and information
brew "whois"

# bat is a better cat
brew "bat"

# ncdu is a better tool for showing directory sizes
brew "ncdu"

# tldr is like man, but better
brew "tldr"

# fd is a find replacement
brew "fd" 

# cloudflared client
brew "cloudflare/cloudflare/cloudflared"