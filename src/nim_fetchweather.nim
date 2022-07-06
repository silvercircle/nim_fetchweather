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

import std/[os, times, json]
import context

import data/[datahandler, datahandler_cc, datahandler_owm]

proc main(): cint
when isMainModule:
  discard os.exitStatusLikeShell(main())

proc run(dh: DataHandler): int =
  if dh.readFromApi() == 0:
    if dh.currentResult["data"]["status"]["code"].getStr() == "success" and
        dh.forecastResult["data"]["status"]["code"].getStr() == "success":
      if dh.populateSnapshot():
        echo dh.convertPressure(1013.0)
        echo dh.convertWindspeed(18.0)
        echo dh.degToBearing(wind_direction = 195)
        echo dh.getCondition(20000)
        echo "Time is: ", now()
        echo dh.currentResult["data"]["status"]
        return 0
    else:
      return -1
  else:
    return -1


proc main(): cint =
  CTX.init()
  var
    data: DataHandler
  let api = "CC"

  if api == "CC":
    data = DataHandler_CC()
    discard run(data)
  elif api == "OWM":
    data = DataHandler_OWM()
    discard data.populateSnapshot()

  system.quit(0)
