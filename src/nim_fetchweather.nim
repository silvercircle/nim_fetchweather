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

import std/[os, json, parseopt, strformat]
import context, sql

import data/[datahandler, datahandler_cc, datahandler_owm, datahandler_aw, datahandler_vc]

proc main(): cint
when isMainModule:
  discard os.exitStatusLikeShell(main())

proc run(dh: var DataHandler): int =
  var
    res: int
  if CTX.cfg.cached:
    res = dh.readFromCache(dh.getAPIId())
  else:
    res = dh.readFromApi()
    dh.writeStats(dh.getAPIId())
    # online operation failed, try the cache
    if res == -1 and CTX.cfg.fallback:
      res = dh.readFromCache(dh.getAPIId())
  if res == 0:
    if dh.populateSnapshot():
      if not CTX.cfg.silent:
        dh.doOutput(stdout)
      if CTX.cfg.do_dump:
        var
          f: File
        try:
          debugmsg fmt"dumping to {CTX.cfg.dumpfile}"
          f = open(CTX.cfg.dumpfile, fmAppend)
          dh.doOutput(f)
          f.close()
        except:
          LOG_ERR(fmt"run(): Cannot open the dumpf file. {getCurrentExceptionMsg()}")
      sql.writeSQL(data = dh)
      return 0
    else:
      return -1
  else:
    return -1

proc main(): cint =
  var
    data: DataHandler
    argCtr: int
    res: int

  CTX.init()

  # command line optinos allow some overriding settings in the cfg file

  for kind, key, value in getOpt():
    case kind:
    of cmdArgument:
      argCtr.inc
    of cmdLongOption, cmdShortOption:
      case key:
      of "api":                               # allows to override the default api (OWM)
        if value == "OWM" or value == "CC" or value == "AW" or value == "VC":
          CTX.cfg.api = value
      of "apikey":
        if value.len != 0:                    # allows to override the apikey
          CTX.cfg.apikey = value
      of "silent":                            # --silent - produce no output on stdout
        CTX.cfg.silent = true
      of "nodb":                              # --nodb - do not write to the DB
        CTX.cfg.no_db = true
      of "dump":                              # --dump - dump to a file
        CTX.cfg.do_dump = true
      of "dumpfile":
        CTX.cfg.dumpfile = value
      of "cached", "offline":                 # --cached - use cached json
        CTX.cfg.cached = true
      of "fallbackoffline":                   # use cache in case online operation fails
        CTX.cfg.fallback = true
      else:
        echo "Unknown option: ", key
    of cmdEnd:
      discard

  let api = CTX.cfg.api

  if api == "CC":
    data = DataHandler_CC(api_id: "CC")
    if run(data) != 0:
      res = -1
  elif api == "OWM":
    data = DataHandler_OWM(api_id: "OWM")
    if run(data) != 0:
      res = -1
  elif api == "AW":
    data = DataHandler_AW(api_id: "AW")
    if run(data) != 0:
      res = -1
  elif api == "VC":
    data = DataHandler_VC(api_id: "VC")
    if run(data) != 0:
      res = -1
  CTX.finalize()
  system.quit(res)
