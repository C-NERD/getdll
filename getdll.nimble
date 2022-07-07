# Package

version       = "0.1.0"
author        = "C-NERD"
description   = "Tool for getting dll files for windos applications"
license       = "MIT"
srcDir        = "src"
bin           = @["getdll"]


# Dependencies

requires "nim >= 1.0.0", "nimcrypto >= 0.5.4"
