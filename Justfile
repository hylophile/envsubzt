test:
    zig test ./src/main.zig -fno-llvm -fno-lld

run:
    zig run src/main.zig -fno-llvm -fno-lld

# build:
# zig build -fno-llvm -fno-lld

watch:
    watchexec --clear clear -r "zig build && echo hi '\${EDITOR}\n' | ./zig-out/bin/envsubzt"
