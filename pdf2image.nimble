# Package

version       = "0.1.0"
author        = "bung87"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["pdf2image"]


# Dependencies

requires "nim >= 1.0.0"
requires "struct"
requires "filetype"
requires "nimtesseract"