import utils/[utils]
import std/[strutils, os]
import context, json as json

proc main(): cint


when isMainModule:
  discard os.exitStatusLikeShell(main())

proc main(): cint =
  CTX.init()
  CTX.greeter()
  CTX.id = 1223

