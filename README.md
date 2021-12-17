# lua-apk
Tool for unpack/repack APK files from SAO Lost Song
Running on luajit 2.1.0

To unpack, you need to create 'data' directory and add the files to be unpacked there. 

To repack files, you need to create 'repack' directory and add the files there that need to be replaced in the original APK. 
The path to the file must match exactly how it was unpacked.

## Usage
```
luajit main.lua repack
luajit main.lua unpack
```

## Dependencies:

- luafilesystem
- zlib