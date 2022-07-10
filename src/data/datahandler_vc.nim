{.warning[CStringConv]: off.}
{.warning[LockLevel]: off.}
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

#[
  * this implements the VisualCrossing API to fetch current conditions and a
  * 3 days forecast
]#
import datahandler
import std/[json, logging, strformat, parsecfg, tables]
from std/strutils import replace
import libcurl
import "../context"
import "../utils/utils"
import "../utils/stats" as S
import times

# this requires the icons2 iconSet to be selected via the API call!
var icons1: Table[string, char] = {
  "clear-day":            'a',        "clear-night":          'A',
  "cloudy":               'e',        "partly-cloudy-day":    'c',
  "partly-cloudy-night":  'C',        "fog":                  '0',
  "rain":                 'j',        "showers-day":          'g',
  "showers-night":        'g',        "snow":                 'o',
  "show-showers-day":     'o',        "snow-showers-night":   'O',
  "thunder-showers-day":  'k',        "thunder-showers-night":'K',
  "thunder-rain":         'k' }.toTable()

type DataHandler_VC* = ref object of DataHandler
  api_id*: string

method construct*(this: DataHandler_VC): DataHandler_VC {.base.} =
  echo "constructing a datahandler VC"
  return this

method getAPIId*(this: DataHandler_VC): string =
  return this.api_id

method getIcon(this: DataHandler_VC, code: string = "clear-day"): char =
  var
    symbol: char = 'c'
  try:
    symbol = icons1[code]
  except:
    symbol = 'c'
  return symbol

# checks if the required Json Nodes are in the result and properly filled
method checkRawDataValidity*(this: DataHandler_VC): bool =
  # if it throws, there is a problem
  debugmsg "Check JSON data validity for VC"
  try:
    if this.currentResult["currentConditions"]["datetimeEpoch"].getInt() != 0 and
        this.currentResult["days"][0]["datetimeEpoch"].getInt() != 0:
          return true
    else:
      context.LOG_ERR(fmt"VC: checkRawDataValidity(): validity check failed, aborting")
      debugmsg "raw data check failed"
      return false
  except:
    debugmsg "raw data check: exception"
    context.LOG_ERR(fmt"VC: checkRawDataValidity(): exception {getCurrentExceptionMsg()}")
    return false

# read from the json api, make sure, data is valid
method readFromAPI*(this: DataHandler_VC): int =
  var
    baseurl, url: string
    ret: Code
    res: int32 = -1

  let webData: ref string = new string
  let curl = libcurl.easy_init()

  this.updateStats(api = this.api_id)

  baseurl = CTX.cfgFile.getSectionValue("VC", "baseurl", "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/___LOC___?unitGroup=metric&include=events,days,hours,alerts,current&contentType=json&key=")
  if CTX.cfg.apikey != "none":
    baseurl.add(CTX.cfg.apikey)
  else:
    baseurl.add(CTX.cfgFile.getSectionValue("VC", "apikey", "none"))

  let loc = CTX.cfgFile.getSectionValue("VC", "loc", "")
  url = replace(baseurl, "___LOC___", by = loc)

  debugmsg fmt"VC: The url is {url}"
  debugmsg fmt"The loc is {loc}"

  context.LOG_INFO(fmt"VC readFromApi() request one-call data from {url}")
  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)

  # VC does not use separate requests for forecasts. They offer an one-call API.
  this.forecastResult = json.parseJson """{"data_VC": {"status": {"code": "success"}}}"""
  # fetch the current conditions. For VC, this includes all the forecast
  ret = curl.easy_perform()
  if ret == E_OK:
    try:
      this.currentResult = json.parseJson(webData[])
      if this.checkRawDataValidity() == true:
        res = 0
      else:
        res = -1
    except:
      context.LOG_ERR(fmt"VC:readFromApi(), Exception: {getCurrentExceptionMsg()}")
      debugmsg "readFromApi, possible parser exception" & getCurrentExceptionMsg()
      res = -1
  else:
    res = -1

  if res == 0:
    this.writeCache("VC")
    this.stats.requests_today.inc
    this.stats.requests_all.inc
    return res
  else:
    this.stats.requests_today.inc
    this.stats.requests_all.inc
    this.stats.requests_failed.inc
    # try to read cached data
    context.LOG_ERR(fmt"VC: readFromApi() failed, trying cached data")

# populate DataHandler.p (type DataPoint) with current and 3 days
# forecast
method populateSnapshot*(this: DataHandler_VC): bool =
  var
    n, f, h: json.JsonNode

  context.LOG_INFO(fmt"VC:populateSnapshot()")

  n = this.currentResult["currentConditions"]
  f = this.currentResult["days"][0]

  this.p.valid = true
  this.p.api = "VC"

  # times
  this.p.sunriseTime = times.fromUnix(n["sunriseEpoch"].getInt())
  this.p.sunsetTime = times.fromUnix(n["sunsetEpoch"].getInt())
  this.p.timeRecorded = times.fromUnix(n["datetimeEpoch"].getInt())
  this.p.timeRecordedAsText = times.format(this.p.timeRecorded, "HH:mm", times.local())
  this.p.sunsetTimeAsString = times.format(this.p.sunsetTime, "HH:mm", times.local())
  this.p.sunriseTimeAsString = times.format(this.p.sunriseTime, "HH:mm", times.local())

  this.p.is_day = (if this.p.timeRecorded > this.p.sunriseTime and this.p.timeRecorded < this.p.sunsetTime: true else: false)
  this.p.weatherCode = 0
  this.p.timeZone = this.currentResult["timezone"].getStr()
  this.p.conditionAsString = n["conditions"].getStr()
  this.p.weatherSymbol = this.getIcon(n["icon"].getStr())

  # temps
  this.p.temperature = n["temp"].getFloat()
  this.p.temperatureApparent = n["feelslike"].getFloat()
  this.p.temperatureMax = f["tempmax"].getFloat()
  this.p.temperatureMin = f["tempmin"].getFloat()

  # wind stuff
  this.p.windDirection = n["winddir"].getFloat().int
  this.p.windSpeed = this.convertWindspeed(n["windspeed"].getFloat() / 3.6)
  try:
    this.p.windGust = this.convertWindspeed(h["windgust"].getFloat() / 3.6)
  except:
    this.p.windGust = 0

  this.p.windBearing = this.degToBearing(this.p.windDirection)
  this.p.windUnit = CTX.cfg.wind_unit

  this.p.visibility = this.convertVis(n["visibility"].getFloat() * 1000)

  this.p.pressureSeaLevel = this.convertPressure(n["pressure"].getFloat())
  this.p.humidity = n["humidity"].getFloat()

  # daily forecasts, 3 days. TODO: make it customizable?
  for i in countup(0, 2):
    this.daily[i].code = this.getIcon(this.currentResult["days"][i + 1]["icon"].getStr())
    this.daily[i].temperatureMin = this.currentResult["days"][i + 1]["tempmin"].getFloat()
    this.daily[i].temperatureMax = this.currentResult["days"][i + 1]["tempmax"].getFloat()
    this.daily[i].weekDay = times.format(times.fromUnix(this.currentResult["days"][i + 1]["datetimeEpoch"].getInt()), "ddd", times.local())

  this.p.haveUVI = true
  this.p.uvIndex = n["uvindex"].getFloat()

  this.p.dewPoint = n["dew"].getFloat()

  this.p.precipitationProbability = f["precipprob"].getFloat()

  this.p.precipitationIntensity = n["precip"].getFloat()
  try:
    let preciptype = n["preciptype"][0]
    this.p.precipitationType = 1
    this.p.precipitationTypeAsString = preciptype.getStr()
  except:
    this.p.precipitationType = 0
    this.p.precipitationIntensity = 0

  this.p.cloudCover = n["cloudcover"].getFloat()
  this.p.apiId = this.api_id
  return true