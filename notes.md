```bash
$cat postbuild.sh
#!/bin/bash
rm -rf "/Applications/Dockerinfo.app"
mv "/Users/frak/Library/Developer/Xcode/DerivedData/Dockerinfo-fqxgemwvyjkgsaajnxkhotkbabhb/Build/Products/Debug/Dockerinfo.app/" /Applications
./bitbar-bundler "/Applications/Dockerinfo.app" /Users/frak/Documents/BitBarPlugins/dockerinfo.365d.py
spctl -a -v "/Applications/Dockerinfo.app"
[11:57 PM][frak@frakbookpro15][~/git/employees/Frakalog/bitbar/Scripts] branch:(master***)
$cat bitbar-bundler
#!/bin/bash
[ "$#" -ge "2" ] || { echo "usage: $0 /path/to/BitBar.app /path/to/first-plugin /path/to/second-plugin ..."; exit 1; }

codesign --deep --force --verbose --sign - "$1"
app="$1/Contents/MacOS/"

shift

# copy plugins into the app's executables directory
cp -v "$@" "$app"

# ensure they are executable
chmod -R +x "$app"

#Added by FRAK
codesign --force --deep --verify --verbose --sign "Developer ID Application: Farqed Al Nuaimy (7G2GKABE9F)" "$app"../../
```
