#[
 * MIT License
 *
 * Copyright (c) 2021 Alex Vie (silvercircle@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * This class handles API specific stuff for the ClimaCell Weather API.
 *]#

# printf like C

import std/strformat
import "../context" as C

proc printf*(format: cstring): cint {.importc, header: "<stdio.h>", varargs.}
proc fprintf*(stream: File, format: cstring): cint {.importc, header: "<stdio.h>", varargs.}
proc sprintf*(str: cstring, format: cstring): cint {.header: "<stdio.h>", importc: "sprintf", varargs.}
proc snprintf*(str: cstring, len: int, format: cstring): cint {.header: "<stdio.h>", importc: "snprintf", varargs.}
proc vsprintf*(str: var cstring, format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc vfprintf*(stream: File, format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc vprintf*(format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc fputs*(str: char, stream: File): cint {.importc, header: "<stdio.h>".}
proc puts*(str: char): cint {.importc, header: "<stdio.h>".}
proc printf_s*(format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc fprintf_s*(stream: File, format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc wprintf*(format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc fwprintf*(stream: File, format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc wprintf_s*(format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc fwprintf_s*(stream: File, format: cstring, arg: varargs[typed, `$`]): cint {.importc, header: "<stdio.h>".}
proc fwrite*(formatstr: cstring, size: cuint, nmemb: cuint, stream: File): cint {.importc, header: "<stdio.h>".}

proc curlWriteFn*(buffer: cstring, size: int, count: int, outstream: pointer): int =
  let outbuf = cast[ref string](outstream)
  outbuf[] &= buffer
  result = size * count

proc show_help*(): void =
  let cfgfilepath = C.CTX.getCfgFilePath()
  let datadir = C.CTX.getDataDirPath()

  echo fmt"""USAGE IS: nim_fetchweather [options]
Configuration is read from: {cfgfilepath}

Allowed command line options are:
--help -h:        Show this help
--version -v:     Show version information
--apikey=key      Override apikey with this value
                  A valid API key is mandatory for proper operation!
--api=CODE        Use API (allowed values for CODE are VC, CC, AW, OWM)
                  (case sensitive!)
                  VC: Visual Crossing API
                  CC: tomorrow.io (formerly ClimaCell)
                  AW: AccuWeather
                  OWM:Open Weather Map.
--silent, -s      Produce no output on stdout
--dump, -d        Dump output to file. Files will be created in the data dir
                  ({datadir})
                  Filename will be dump_DATETIME_IN_ISO_FORMAT
--dumpfile        Create dump in this file. The directory must exist and must
                  have write access.
--cached, -c      used cached data (if available). Do NOT go online
--offline, -o     same as --cached
--nodb            Do not record to database.
--location=LOC    override location from configuration file. LOC must be in the
                  format lat,lon. E.g. 15.39938,16.38389
--fallbackoffline If online operation fails, try the cache. If that fails as
                  well, bail out with an error.
"""

proc show_version*(): void =
  echo """This is nim_fetchweather version 0.9.1
(C) 2022 by Alex Vie <silvercircle at gmail dot com>

This software is free software governed by the MIT License.
Please visit https://github.com/silvercircle/nim_fetchweather
for more information about this software and copyright information."""

