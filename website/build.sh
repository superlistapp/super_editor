#!/bin/bash

# Get flutter and set a shorthand command for it
git clone https://github.com/flutter/flutter.git
FLUTTER=flutter/bin/flutter

# Choose the correct Flutter channel & version, and enable web support.
#
# We're using Flutter 2.0.4 on the stable channel, since that's one of
# the versions that works fine with the SuperEditor. Newer Flutter versions
# got rid of some of the components that the editor is currently using, so
# it's important to lock the version down so that the build works.
DIR=$("${FLUTTER} channel stable" >& /dev/stdout)
(cd flutter && git checkout 2.0.4)
$FLUTTER precache
$FLUTTER config --enable-web

# Build the website in release mode
$FLUTTER build web --release
