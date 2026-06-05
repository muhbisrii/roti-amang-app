#!/bin/bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:pwd/flutter/bin"
flutter config --no-analytics
flutter build web --release