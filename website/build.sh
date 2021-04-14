#!/bin/bash

# Get flutter and set a shorthand command for it
git clone https://github.com/flutter/flutter.git
FLUTTER=flutter/bin/flutter

# Choose the correct Flutter channel & version, enable web support
DIR=$("${FLUTTER} channel stable" >& /dev/stdout)
(cd flutter && git checkout 2.0.4)
$FLUTTER precache
$FLUTTER config --enable-web

# Build the website in release mode
$FLUTTER build web --release
