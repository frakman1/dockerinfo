#!/bin/bash
rm -rf "/Applications/Dockerinfo.app"
mv "/Users/frak/Library/Developer/Xcode/DerivedData/Dockerinfo-fqxgemwvyjkgsaajnxkhotkbabhb/Build/Products/Debug/Dockerinfo.app/" /Applications
./bitbar-bundler "/Applications/Dockerinfo.app" /Users/frak/Documents/BitBarPlugins/dockerinfo.365d.py
spctl -a -v "/Applications/Dockerinfo.app"
