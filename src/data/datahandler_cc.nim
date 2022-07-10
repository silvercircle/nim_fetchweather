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
import std/[json, parsecfg, tables, strformat]
import libcurl
import "../utils/utils" as utils
import "../context" as C
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

var
  precipType = [ "", "Rain", "Snow", "Freezing Rain", "Ice Pellets" ]

type DataHandler_CC* = ref object of DataHandler
  api_id*: string

method getCondition*(this: DataHandler_CC, c: int): string =
  try:
    return conditions[c]
  except:
    return "Clear(E)"

method getAPIId*(this: DataHandler_CC): string =
  return this.api_id

method getIcon(this: DataHandler_CC, code: int = 0, is_day: bool = true): char =
  var
    s: string
  try:
    if code > 0:
      s = icons[code]
    else:
      s = icons[this.p.weatherCode]
    return (if is_day: cast[char](s[0]) else: cast[char](s[1]))
  except:
    return 'a'

# checks if the required Json Nodes are in the result and properly filled
method checkRawDataValidity*(this: DataHandler_CC): bool =
  # if it throws, there is a problem
  debugmsg "Check JSON data validity for CC"
  try:
    if this.currentResult["data"]["timelines"][0]["timestep"].getStr() == "current" and
       this.currentResult["data"]["timelines"][0]["intervals"][0]["values"]["weatherCode"].getInt() != 0 and
       this.forecastResult["data"]["timelines"][0]["intervals"][1]["values"]["weatherCode"].getInt() != 0:
          return true
    else:
      C.LOG_ERR(fmt"OWM: checkRawDataValidity(): validity check failed, aborting")
      debugmsg "raw data check failed"
      return false
  except:
    debugmsg "raw data check: exception"
    C.LOG_ERR(fmt"OWM: checkRawDataValidity(): exception {getCurrentExceptionMsg()}")
    return false

method readFromAPI*(this: DataHandler_CC): int =
  var
    baseurl, url, forecasturl: string
    ret: Code
    res: int = 0

  let webData: ref string = new string
  let webData_fc: ref string = new string

  this.updateStats(api = this.api_id)

  let curl = libcurl.easy_init()

  baseurl = CTX.cfgFile.getSectionValue("CC", "baseurl", "https://data.climacell.co/v4/timelines?&apikey=")
  baseurl.add(CTX.cfgFile.getSectionValue("CC", "apikey", "none"))
  baseurl.add("&location=" & $CTX.cfgFile.getSectionValue("CC", "loc", "0,0"))
  baseurl.add("&timezone=" & $CTX.cfgFile.getSectionValue("CC", "timezone","Europe/Vienna"))
  url.add(baseurl)
  url.add("&fields=weatherCode,temperature,temperatureApparent,visibility,windSpeed,windDirection,")
  url.add("precipitationType,precipitationProbability,pressureSeaLevel,windGust,cloudCover,cloudBase,")
  url.add("cloudCeiling,humidity,precipitationIntensity,dewPoint&timesteps=current&units=metric")

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
    except:
      res = -1
      C.LOG_ERR(fmt"CC: readFromApi(): Exception {getCurrentExceptionMsg()}")
  else:
    C.LOG_ERR(fmt"CC: readFromApi(): curl.easy_perform() returned error {ret}")
    res = -1

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
    except:
      C.LOG_ERR(fmt"CC: readFromApi(): Exception {getCurrentExceptionMsg()}")
      res = -1
  else:
    C.LOG_ERR(fmt"CC: readFromApi(): curl.easy_perform() returned error {ret}")
    res = -1

  if this.checkRawDataValidity():
    this.writeCache("CC")
    this.stats.requests_today += 2
    this.stats.requests_all += 2
  else:
    res = -1
    this.stats.requests_today += 2
    this.stats.requests_all += 2
    this.stats.requests_failed += 1
  return res

method populateSnapshot*(this: DataHandler_CC): bool =
  var n, f: json.JsonNode

  #try:
  n = this.currentResult["data"]["timelines"][0]["intervals"][0]["values"]
  f = this.forecastResult["data"]["timelines"][0]["intervals"][0]["values"]

  debugmsg "setup done"
  this.p.valid = true
  this.p.api = "OWM"

  # times
  this.p.sunriseTime = times.parseTime(f["sunriseTime"].getStr(), "yyyy-MM-dd'T'HH:mm:sszz", times.local())
  this.p.sunsetTime = times.parseTime(f["sunsetTime"].getStr(), "yyyy-MM-dd'T'HH:mm:sszz", times.local())
  this.p.timeRecorded = times.getTime()
  this.p.timeRecordedAsText = times.format(this.p.timeRecorded, "HH:mm", times.local())
  this.p.sunsetTimeAsString = times.format(this.p.sunsetTime, "HH:mm", times.local())
  this.p.sunriseTimeAsString = times.format(this.p.sunriseTime, "HH:mm", times.local())

  this.p.is_day = (if this.p.timeRecorded > this.p.sunriseTime and this.p.timeRecorded < this.p.sunsetTime: true else: false)
  this.p.weatherCode = n["weatherCode"].getInt()
  this.p.weatherSymbol = this.getIcon(is_day = this.p.is_day)
  this.p.timeZone = CTX.cfgFile.getSectionValue("OWM", "timezone")
  this.p.conditionAsString = this.getCondition(this.p.weatherCode)

  # temps
  this.p.temperature =          n["temperature"].getFloat()
  this.p.temperatureApparent =  n["temperatureApparent"].getFloat()
  this.p.temperatureMax =       f["temperatureMax"].getFloat()
  this.p.temperatureMin =       f["temperatureMin"].getFloat()

  # wind stuff
  this.p.windSpeed =      this.convertWindspeed(n["windSpeed"].getFloat())
  this.p.windGust =       this.convertWindspeed(n["windGust"].getFloat())
  this.p.windDirection =  n["windDirection"].getInt()
  this.p.windBearing =    this.degToBearing(this.p.windDirection)
  this.p.windUnit =       CTX.cfg.wind_unit

  this.p.visibility = this.convertVis(n["visibility"].getFloat())

  this.p.pressureSeaLevel = this.convertPressure(n["pressureSeaLevel"].getFloat())
  this.p.humidity = n["humidity"].getFloat()

  # daily forecasts, 3 days. TODO: make it customizable?
  let base = this.forecastResult["data"]["timelines"][0]["intervals"]
  for i in countup(0, 2):
    this.daily[i].code = this.getIcon(base[i + 1]["values"]["weatherCode"].getInt(), true)
    this.daily[i].temperatureMin = base[i + 1]["values"]["temperatureMin"].getFloat()
    this.daily[i].temperatureMax = base[i + 1]["values"]["temperatureMax"].getFloat()
    this.daily[i].weekDay = times.format(times.parseTime(base[i + 1]["startTime"].getStr(),
                                                        "yyyy-MM-dd'T'HH:mm:sszzz", local()), "ddd", times.local())

  this.p.haveUVI = false
  this.p.uvIndex = 0

  this.p.dewPoint = n["dewPoint"].getFloat()
  this.p.precipitationProbability = n["precipitationProbability"].getFloat()
  this.p.precipitationIntensity = n["precipitationIntensity"].getFloat()
  if this.p.precipitationIntensity > 0:
    this.p.precipitationType = n["precipitationType"].getInt()
    this.p.precipitationTypeAsString = (if this.p.precipitationType >= 0 and this.p.precipitationType <= 4:
                                        precipType[this.p.precipitationType] else: "")
  else:
    this.p.precipitationType = 0
    this.p.precipitationTypeAsString = ""

  this.p.cloudCover = n["cloudCover"].getFloat()
  this.p.cloudBase = n["cloudBase"].getFloat()
  this.p.cloudCeiling = n["cloudCeiling"].getFloat()
  this.p.apiId = this.api_id
  #except:
  #  C.LOG_ERR(fmt"CC: populateSnapshot() - exception: {getCurrentExceptionMsg()}")
  #  return false
  return true