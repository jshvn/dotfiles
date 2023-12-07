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
#  Taps                       #
###############################

# none!

###############################
#  Binaries                   #
###############################

# none!

brew_install_or_upgrade("python3")
brew_install_or_upgrade("docker")