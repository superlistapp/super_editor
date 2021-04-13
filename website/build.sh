#!/bin/bash
cd website

# Use the same Flutter channel as the current project does
FLUTTER_CHANNEL=`grep channel: .metadata | sed 's/  channel: //g'`

# Get flutter and set a shorthand command for it
git clone https://github.com/flutter/flutter.git
FLUTTER=flutter/bin/flutter

# Choose the correct Flutter channel, enable web support
DIR=$("${FLUTTER} channel ${FLUTTER_CHANNEL}" >& /dev/stdout)
$FLUTTER config --enable-web

# Upgrade Flutter if needed
if [[ $DIR == *"Your branch is behind"* ]]; then
  $FLUTTER upgrade
fi

# Build the website in release mode
$FLUTTER build web --release
