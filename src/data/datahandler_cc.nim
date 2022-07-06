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
{.warning[LockLevel]: off.}

import datahandler
import std/[json, parsecfg, tables]
import libcurl
import "../utils/utils" as utils
import "../context"
import times

var conditions: Table[int, string] = {
       1000: "Clear", 1001: "Cloudy",
       1100: "Mostly Clear", 1101: "Partly Cloudy",
       1102: "Mostly Cloudy", 2000: "Fog",
       2100: "Light Fog", 3000: "Light Wind",
       3001: "Wind", 3002: "Strong Wind",
       4000: "Drizzle", 4001: "Rain",
       4200: "Light Rain", 4201: "Heavy Rain",
       5000: "Snow", 5001: "Flurries",
       5100: "Light Snow", 5101: "Heavy Snow",
       6000: "Freezing Drizzle", 6001: "Freezing Rain",
       6200: "Light Freezing Rain", 6201: "Heavy Freezing Rain",
       7000: "Ice Pellets", 7001: "Heavy Ice Pellets",
       7102: "Light Ice Pellets", 8000: "Thunderstorm"}.toTable()

var icons: Table[int, string] = {
      1000: "aA", 1001: "ef",
      1100: "bB", 1101: "cC",
      1102: "dD", 2000: "00",
      2100: "77", 3000: "99",
      3001: "99", 3002: "23",
      4000: "xx", 4001: "gG",
      4200: "gg", 4201: "jj",
      5000: "oO", 5001: "xx",
      5100: "oO", 5101: "ww",
      6000: "xx", 6001: "yy",
      6200: "ss", 6201: "yy",
      7000: "uu", 7001: "uu",
      7102: "uu", 8000: "kK"}.toTable()

type DataHandler_CC* = ref object of DataHandler

method getCondition*(this: DataHandler_CC, c: int): string =
  try:
    return conditions[c]
  except:
    return "Clear(E)"

method readFromAPI*(this: DataHandler_CC): int =
  var
    baseurl, url, forecasturl: string
    ret: Code

  let webData: ref string = new string
  let webData_fc: ref string = new string

  let curl = libcurl.easy_init()

  baseurl = CTX.cfgFile.getSectionValue("CC", "baseurl", "https://data.climacell.co/v4/timelines?&apikey=")
  baseurl.add(CTX.cfgFile.getSectionValue("CC", "apikey", "none"))
  baseurl.add("&location=" & $CTX.cfgFile.getSectionValue("CC", "loc", "0,0"))
  baseurl.add("&timezone=" & $CTX.cfgFile.getSectionValue("CC", "timezone","Europe/Vienna"))
  url.add(baseurl)
  url.add("&fields=weatherCode,temperature,temperatureApparent,visibility,windSpeed,windDirection,")
  url.add("precipitationType,precipitationProbability,pressureSeaLevel,windGust,cloudCover,cloudBase,")
  url.add("cloudCeiling,humidity,precipitationIntensity,dewPoint&timesteps=current&units=metric")

  debugmsg "THE URL IS  " & url

  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)

  # fetch the current conditions
  ret = curl.easy_perform()
  if ret == E_OK:
    try:
      this.currentResult = json.parseJson(webData[])
      this.currentResult["data"]["status"] = %* {"code": "success"}
    except:
      this.currentResult["data"]["status"] = %* {"code": "failure"}
  else:
    return -1

  # build forecast url
  forecasturl.add(baseurl)
  forecasturl.add("&fields=weatherCode,temperatureMax,temperatureMin,sunriseTime,sunsetTime,moonPhase,")
  forecasturl.add("precipitationType,precipitationProbability&timesteps=1d&startTime=")

  discard curl.easy_setopt(OPT_WRITEDATA, webData_fc)
  discard curl.easy_setopt(OPT_URL, forecasturl)

  # fetch the forecast
  ret = curl.easy_perform()
  if ret == E_OK:
    # request was ok, but we have to make sure parsing won't fail
    try:
      this.forecastResult = json.parseJson(webData_fc[])
      this.forecastResult["data"]["status"] = %* {"code": "success"}
    except:
      this.forecastResult["data"]["status"] = %* {"code": "failure"}
    this.writeCache(prefix = "CC")
    return 0
  else:
    return -1


method populateSnapshot*(this: DataHandler_CC): bool =
  var n, f: json.JsonNode

  n = this.currentResult["data"]["timelines"][0]["intervals"][0]["values"]
  f = this.forecastResult["data"]["timelines"][0]["intervals"][0]["values"]

  echo times.parse(f["sunriseTime"].getStr(), "yyyy-MM-dd'T'HH:mm:sszz", times.local())
  echo times.parse(f["sunsetTime"].getStr(), "yyyy-MM-dd'T'HH:mm:sszz", times.local())
  this.p.is_day = true
  this.p.weatherCode = n["weatherCode"].getInt()
  this.p.timeZone = CTX.cfgFile.getSectionValue("CC", "timezone")
  this.p.conditionAsString = this.getCondition(n["weatherCode"].getInt())
  try:
    echo n["dewPoint"]
  except:
    echo getCurrentExceptionMsg()
    return false

  return true
