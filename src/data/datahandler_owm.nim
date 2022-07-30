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
  * this implements the OpenWeatherMap API to fetch current conditions and a
  * 3 days forecast
]#
import datahandler
import std/[json, logging, strformat, parsecfg, strutils]
import libcurl
import "../context"
import "../utils/utils"
import "../utils/stats" as S
import times

type DataHandler_OWM* = ref object of DataHandler
  api_id*: string

method construct*(this: DataHandler_OWM): DataHandler_OWM {.base.} =
  echo "constructing a datahandler OWM"
  return this

method getAPIId*(this: DataHandler_OWM): string =
  return this.api_id

method getIcon(this: DataHandler_OWM, code: int = 100, is_day: bool = true): char =
  var
    symbol: char = 'c'
    daylight: bool = this.p.is_day

  if code >= 200 and code <= 299:         # thunderstorm
    symbol = (if daylight: 'k' else: 'K')

  if code >= 300 and code <= 399:         # drizzle
    symbol = 'x'

  if code == 800:
    symbol = 'a'

  if code >= 500 and code <= 599:    # rain
    case code:
      of 511:
        symbol = 's'
      of 502, 503, 504:
        symbol = 'j'
      else:
        symbol = (if daylight: 'g' else: 'G')

  if code >= 600 and code <= 699:         # snow
    case code:
      of 602, 522:
        symbol = 'w'
      of 504:
        symbol = 'j'
      else:
        symbol = (if daylight: 'o' else: 'O')

  if code >= 801 and code <= 899:         # other
    case code:
      of 801:
        symbol = (if daylight: 'b' else: 'B')
      of 802:
        symbol = (if daylight: 'c' else: 'C')
      of 803:
        symbol = (if daylight: 'e' else: 'f')
      of 804:
        symbol = (if daylight: 'd' else: 'D')
      else:
        symbol = (if daylight: 'c' else: 'C')

  if code >= 700 and code <= 799:
    case code:
      of 711, 741, 701:
        symbol = '0'
      else:
        symbol = (if daylight: 'c' else: 'C')

  return symbol

# checks if the required Json Nodes are in the result and properly filled
method checkRawDataValidity*(this: DataHandler_OWM): bool =
  # if it throws, there is a problem
  debugmsg "Check JSON data validity for OWM"
  try:
    if this.currentResult["current"]["dt"].getInt() != 0 and
        this.currentResult["hourly"][0]["dt"].getInt() != 0 and
        this.currentResult["daily"][0]["dt"].getInt() != 0:
          return true
    else:
      context.LOG_ERR(fmt"OWM: checkRawDataValidity(): validity check failed, aborting")
      debugmsg "raw data check failed"
      return false
  except:
    debugmsg "raw data check: exception"
    context.LOG_ERR(fmt"OWM: checkRawDataValidity(): exception {getCurrentExceptionMsg()}")
    return false

# read from the json api, make sure, data is valid
method readFromAPI*(this: DataHandler_OWM): int =
  var
    baseurl, url: string
    ret: libcurl.Code
    res: int32 = -1

  let webData: ref string = new string
  let curl = libcurl.easy_init()

  this.updateStats(api = this.api_id)

  baseurl = CTX.cfgFile.getSectionValue("OWM", "baseurl", "http://api.openweathermap.org/data/2.5/onecall?appid=")
  if CTX.cfg.apikey != "none":
    baseurl.add(CTX.cfg.apikey)
  else:
    baseurl.add(CTX.cfgFile.getSectionValue("OWM", "apikey", "none"))
  let loc = $CTX.cfgFile.getSectionValue("OWM", "loc", "0,0")

  ## OWM does not accept lat,lon as location, they want them separated into lat and lon
  ## so be it.
  let latlon = strutils.split(loc, ",", 2)

  baseurl.add("&lat=" & latlon[0])
  baseurl.add("&lon=" & latlon[1])
  # baseurl.add("&timezone=" & $CTX.cfgFile.getSectionValue("CC", "timezone","Europe/Vienna"))
  url.add(baseurl)
  url.add("&exclude=minutely&units=metric");

  context.LOG_INFO(fmt"OWM readFromApi() request one-call data from {url}")
  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)

  # owm does not use separate requests for forecasts. They offer an one-call API.
  this.forecastResult = json.parseJson """{"data_OWM": {"status": {"code": "success"}}}"""
  # fetch the current conditions. For OWM, this includes all the forecast
  ret = curl.easy_perform()
  if ret == E_OK:
    try:
      this.currentResult = json.parseJson(webData[])
      if this.checkRawDataValidity() == true:
        res = 0
      else:
        res = -1
    except:
      context.LOG_ERR(fmt"OWM:readFromApi(), Exception: {getCurrentExceptionMsg()}")
      res = -1
  else:
    res = -1

  if res == 0:
    this.writeCache("OWM")
    this.stats.requests_today.inc
    this.stats.requests_all.inc
    return res
  else:
    res = -1
    this.stats.requests_today.inc
    this.stats.requests_all.inc
    this.stats.requests_failed.inc
    context.LOG_ERR(fmt"OWM: readFromApi() failed, trying cached data")
  return res

# populate DataHandler.p (type DataPoint) with current and 3 days
# forecast
method populateSnapshot*(this: DataHandler_OWM): bool =
  var
    n, f, h: json.JsonNode

  context.LOG_INFO(fmt"OWM:populateSnapshot()")

  n = this.currentResult["current"]
  f = this.currentResult["daily"][0]
  h = this.currentResult["hourly"][0]

  this.p.valid = true
  this.p.api = "OWM"

  # times
  this.p.sunriseTime = times.fromUnix(n["sunrise"].getInt())
  this.p.sunsetTime = times.fromUnix(n["sunset"].getInt())
  this.p.timeRecorded = times.fromUnix(n["dt"].getInt())
  this.p.timeRecordedAsText = times.format(this.p.timeRecorded, "HH:mm", times.local())
  this.p.sunsetTimeAsString = times.format(this.p.sunsetTime, "HH:mm", times.local())
  this.p.sunriseTimeAsString = times.format(this.p.sunriseTime, "HH:mm", times.local())

  this.p.is_day = (if this.p.timeRecorded > this.p.sunriseTime and this.p.timeRecorded < this.p.sunsetTime: true else: false)
  this.p.weatherCode = n["weather"][0]["id"].getInt()
  this.p.weatherSymbol = this.getIcon(this.p.weatherCode)
  this.p.timeZone = CTX.cfgFile.getSectionValue("OWM", "timezone")
  this.p.conditionAsString = n["weather"][0]["main"].getStr()

  # temps
  this.p.temperature = n["temp"].getFloat()
  this.p.temperatureApparent = n["feels_like"].getFloat()
  this.p.temperatureMax = f["temp"]["max"].getFloat()
  this.p.temperatureMin = f["temp"]["min"].getFloat()

  # wind stuff
  this.p.windSpeed = this.convertWindspeed(n["wind_speed"].getFloat())
  this.p.windGust = this.convertWindspeed(h["wind_gust"].getFloat())
  this.p.windDirection = n["wind_deg"].getInt()
  this.p.windBearing = this.degToBearing(this.p.windDirection)
  this.p.windUnit = CTX.cfg.wind_unit

  this.p.visibility = this.convertVis(n["visibility"].getFloat())

  this.p.pressureSeaLevel = this.convertPressure(n["pressure"].getFloat())
  this.p.humidity = n["humidity"].getFloat()

  # daily forecasts, 3 days. TODO: make it customizable?
  for i in countup(0, 2):
    this.daily[i].code = this.getIcon(this.currentResult["daily"][i + 1]["weather"][0]["id"].getInt(), true)
    this.daily[i].temperatureMin = this.currentResult["daily"][i + 1]["temp"]["min"].getFloat()
    this.daily[i].temperatureMax = this.currentResult["daily"][i + 1]["temp"]["max"].getFloat()
    this.daily[i].weekDay = times.format(times.fromUnix(this.currentResult["daily"][i + 1]["dt"].getInt()), "ddd", times.local())

  this.p.haveUVI = true
  this.p.uvIndex = n["uvi"].getFloat()

  this.p.dewPoint = n["dew_point"].getFloat()
  this.p.precipitationProbability = (if h["pop"].isNil(): 0.0 else: h["pop"].getFloat())

  this.p.precipitationIntensity = 0.0
  if n.contains("rain"):
    this.p.precipitationIntensity = n["rain"]["1h"].getFloat()
  if n.contains("snow"):
    this.p.precipitationIntensity = n["snow"]["1h"].getFloat()

  if this.p.precipitationIntensity > 0:
    this.p.precipitationType = 1
    this.p.precipitationTypeAsString =  (if n.contains("snow"): "Snow" else: "Rain")

  this.p.cloudCover = n["clouds"].getFloat()
  this.p.apiId = this.api_id
  return true
