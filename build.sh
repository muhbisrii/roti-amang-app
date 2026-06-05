#!/bin/bash

Download Flutter versi terbaru saja (sangat cepat)

git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:pwd/flutter/bin"

Matikan analitik agar proses tidak tertahan persetujuan

flutter config --no-analytics

Mulai proses pembuatan website

flutter build web --release