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

var wind_directions*:  array[16, string] = [
      "N", "NNE", "NE",
      "ENE", "E", "ESE",
      "SE", "SSE", "S",
      "SSW", "SW", "WSW",
      "W", "WNW", "NW",
      "NNW"]

proc curlWriteFn*(buffer: cstring, size: int, count: int, outstream: pointer): int =
  let outbuf = cast[ref string](outstream)
  outbuf[] &= buffer
  result = size * count

