# Package
version       = "0.1.0"
author        = "Alex"
description   = "Testing"
license       = "MIT"
srcDir        = "src"
bin           = @["nim_fetchweather"]

# Dependencies

requires "nim >= 1.6.6"

task release, "We just foo around":
    exec("nim compile  -o:build/release/nim_fetchweather -r --threads:on --mm:arc --cc:clang -d:release --opt:speed src/nim_fetchweather.nim")
    #exec("build/release/nim_fetchweather")

task debug, "Debug build":
    exec("nim compile  -o:build/debug/nim_fetchweather -r --threads:on --mm:arc --cc:clang -d:debug --lineDir:on --debuginfo --debugger:native src/nim_fetchweather.nim")
    #exec("build/debug/nim_feathweather")
