# printf interface

# printf like C
proc printf*(format: cstring): cint {.importc, header: "<stdio.h>", varargs.}
proc fprintf*(stream: File, format: cstring): cint {.importc, header: "<stdio.h>".}
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
