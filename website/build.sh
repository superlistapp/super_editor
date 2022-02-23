#!/bin/bash

# Get flutter and set a shorthand command for it
git clone https://github.com/flutter/flutter.git
FLUTTER=flutter/bin/flutter

# Make sure we're on the stable channel & precache web artifacts
$FLUTTER channel stable
$FLUTTER precache --web

# Build the website in release mode
$FLUTTER build web --release
