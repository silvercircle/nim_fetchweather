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

{.warning[CStringConv]: off.}
{.warning[LockLevel]:off.}

import datahandler
import std/json
import "../utils/utils" as utils
import libcurl
import std/parsecfg
import "../context"

type DataHandler_CC* = ref object of DataHandler

method readFromAPI*(this: DataHandler_CC): int =
  var
    baseurl: string
    url: string

  let webData: ref string = new string
  let curl = libcurl.easy_init()

  baseurl = "https://data.climacell.co/v4/timelines?&apikey="
  baseurl.add(CTX.cfgFile.getSectionValue("CC", "apikey"))
  baseurl.add("&location=" & $CTX.cfgFile.getSectionValue("CC", "loc"))
  baseurl.add("&timezone=" & $CTX.cfgFile.getSectionValue("CC", "timezone"))

  url.add(baseurl)
  url.add("&fields=weatherCode,temperature,temperatureApparent,visibility,windSpeed,windDirection,")
  url.add("precipitationType,precipitationProbability,pressureSeaLevel,windGust,cloudCover,cloudBase,")
  url.add("cloudCeiling,humidity,precipitationIntensity,dewPoint&timesteps=current&units=metric")

  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)

  let ret = curl.easy_perform()
  if ret == E_OK:
    this.currentResult = json.parseJson(webData[])
    return 0
  else:
    return -1


method populateSnapshot*(this: DataHandler_CC): void =
  var n: json.JsonNode

  n = this.currentResult["data"]["timelines"][0]["intervals"][0]["values"]
  echo n["weatherCode"]
