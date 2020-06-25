#!/usr/bin/env bash

# find git directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
GITDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

if xcode-select -p 1>/dev/null; then
  echo "Xcode Command Line Tools already installed, skipping installation"
else
  echo "Installing Xcode Command Line Tools"
  # Install Xcode Command Line Tools
  sudo xcode-select --install
  # Accept Xcode license
  sudo xcodebuild -license accept
fi

source "$GITDIR"/defaults.sh