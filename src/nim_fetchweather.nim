import std/[os]
import context

import data/[datahandler, datahandler_cc, datahandler_owm]

proc main(): cint
when isMainModule:
  discard os.exitStatusLikeShell(main())

proc main(): cint =
  CTX.init()
  CTX.greeter()
  var
    data: DataHandler
  let api = "CC"

  if api == "CC":
    data = DataHandler_CC()
    data.populateSnapshot()
  elif api == "OWM":
    data = DataHandler_OWM()
    data.populateSnapshot()

  system.quit(0)
