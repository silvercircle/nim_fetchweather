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

import std/[os, json, parseopt]
import context, sql

import data/[datahandler, datahandler_cc, datahandler_owm]

proc main(): cint
when isMainModule:
  discard os.exitStatusLikeShell(main())

proc run(dh: var DataHandler): int =
  if dh.readFromApi() == 0:
    if dh.currentResult["data_" & dh.getAPIId()]["status"]["code"].getStr() == "success" and
        dh.forecastResult["data_" & dh.getAPIId()]["status"]["code"].getStr() == "success":
      if dh.populateSnapshot():
        dh.doOutput(stdout)
        sql.writeSQL(data = dh)
        return 0
      else:
        return -1
    else:
      return -1
  else:
    return -1

proc main(): cint =
  var
    data: DataHandler
    argCtr: int

  CTX.init()

  # command line optinos allow some overriding settings in the cfg file

  for kind, key, value in getOpt():
    case kind:
    of cmdArgument:
      echo "Got arg ", argCtr, ": \"", key, "\""
      argCtr.inc

    of cmdLongOption, cmdShortOption:
      case key:
      of "api":
        if value == "OWM" or value == "CC":
          CTX.cfg.api = value
      of "apikey":
        if value.len != 0:
          CTX.cfg.apikey = value
      else:
        echo "Unknown option: ", key

    of cmdEnd:
      discard

  let api = CTX.cfg.api

  if api == "CC":
    data = DataHandler_CC(api_id: "CC")
    if run(data) != 0:
      system.quit(-1)
  elif api == "OWM":
    data = DataHandler_OWM(api_id: "OWM")
    if run(data) != 0:
      system.quit(-1)

  system.quit(0)
