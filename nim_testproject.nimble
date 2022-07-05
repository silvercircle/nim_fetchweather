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
    exec("nim compile  --threads:on --mm:arc --cc:clang -d:danger src/nim_fetchweather.nim")
    exec("src/nim_testproject")

task debug, "Debug build":
    exec("nim compile  --threads:on --mm:arc --cc:gcc -d:debug --lineDir:on --debuginfo --debugger:native src/nim_fetchweather.nim")
    exec("src/nim_testproject")
