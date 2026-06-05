#!/bin/bash

1. Vercel akan mendownload mesin Flutter

git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:pwd/flutter/bin"

2. Vercel akan mem-build aplikasinya jadi Website

flutter build web --release