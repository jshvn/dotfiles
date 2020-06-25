#!/usr/bin/env bash

# Install Xcode Command Line Tools
sudo xcode-select --install
# Accept Xcode license
sudo xcodebuild -license accept

source ./defaults.sh