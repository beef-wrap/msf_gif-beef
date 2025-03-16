mkdir libs
mkdir libs\debug
mkdir libs\release

copy msf_gif\msf_gif.h msf_gif\msf_gif.c

clang -c -g -gcodeview -o msf_gif.lib -target x86_64-pc-windows -fuse-ld=llvm-lib -Wall -DMSF_GIF_IMPL msf_gif/msf_gif.c
copy msf_gif.lib libs\debug

clang -c -o msf_gif.lib -target x86_64-pc-windows -fuse-ld=llvm-lib -Wall -DMSF_GIF_IMPL msf_gif/msf_gif.c
move msf_gif.lib libs\release