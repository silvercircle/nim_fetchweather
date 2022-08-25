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
 * This class handles API specific stuff for the AccuWeather Weather API.
 *]#

{.warning[CStringConv]: off.}
{.warning[LockLevel]: off.}

# this implements the AccuWeather(tm) API to fetch
import datahandler
import std/[json, parsecfg, tables, strformat]
import libcurl
import "../utils/utils" as utils
import "../context" as C
import times

var icons_day: Table[int, string] = {
      0001: "aA", 0007: "ef",
      0002: "bB", 0003: "cC",
      0006: "dD", 0011: "00",
      0011: "77", 3000: "99",
      3001: "99", 3002: "23",
      0025: "xx", 0018: "gG",
      0012: "gg", 0018: "jj",
      0022: "oO", 0019: "xx",
      0023: "oO", 0022: "ww",
      0026: "xx", 0026: "yy",
      0026: "ss", 0026: "yy",
      0024: "uu", 0024: "uu",
      0024: "uu", 0015: "kK"}.toTable()

var icons_night: Table[int, string] = {
      0033: "aA", 0038: "ef",
      0034: "bB", 0035: "cC",
      0038: "dD", 0038: "00",
      0037: "77", 3000: "99",
      3001: "99", 3002: "23",
      0025: "xx", 0018: "gG",
      0012: "gg", 0018: "jj",
      0022: "oO", 0019: "xx",
      0023: "oO", 0022: "ww",
      0026: "xx", 0026: "yy",
      0026: "ss", 0026: "yy",
      0024: "uu", 0024: "uu",
      0024: "uu", 0042: "kK"}.toTable()

type DataHandler_AW* = ref object of DataHandler
  api_id*: string

method getAPIId*(this: DataHandler_AW): string =
  return this.api_id

method getIcon(this: DataHandler_AW, code: int = 0, is_day: bool = true): char =
  var
    s: string
    c: int = code
  debugmsg fmt"The code is {code} and is_day is {is_day}"
  try:
    if c > 0:
      case code:
        of 4,5:
          c = 3
        else:
          c = 1
      s = (if is_day: icons_day[c] else: icons_night[c])
    else:
      s = (if is_day: icons_day[this.p.weatherCode] else: icons_night[this.p.weatherCode])
    return (if is_day: cast[char](s[0]) else: cast[char](s[1]))
  except:
    return 'a'

# checks if the required Json Nodes are in the result and properly filled
method checkRawDataValidity*(this: DataHandler_AW): bool =
  # if it throws, there is a problem
  debugmsg "Check JSON data validity for AW"
  try:
    try:
      if this.currentResult.contains("Code"):
        debugmsg "Error message found"
        let msg = this.currentResult["Code"].getStr() & " / " & this.currentResult["Message"].getStr()
        C.LOG_ERR(fmt"AW: checkRawDataValidity(): Api returned error ({msg})")
        return false
    except:
      discard
    debugmsg "check for json validity"
    if this.currentResult[0]["EpochTime"].getInt() != 0 and
       this.forecastResult["Headline"]["EffectiveEpochDate"].getInt() != 0 and
       this.forecastResult["DailyForecasts"][0]["EpochDate"].getInt() != 0:
          return true
    else:
      C.LOG_ERR(fmt"AW: checkRawDataValidity(): validity check failed, aborting")
      debugmsg "raw data check failed"
      return false
  except:
    debugmsg "raw data check: exception"
    C.LOG_ERR(fmt"AW: checkRawDataValidity(): exception {getCurrentExceptionMsg()}")
    return false

# TODO: obtain location code if not specified on command line or in the configuration
#       file. For now, the lockey must be obtained manually and passed via the
#       configuration file or command line option.
method readFromAPI*(this: DataHandler_AW): int =
  var
    baseurl, url, forecasturl, loc_key: string
    ret: Code
    res: int = 0

  let webData: ref string = new string
  let webData_fc: ref string = new string

  this.updateStats(api = this.api_id)

  # location key. AccuWeather does not accept direct location input in the api. The key must be
  # obtained with a separate call.
  loc_key = CTX.cfgFile.getSectionValue("AW", "loc_key", "")

  if loc_key.len == 0:
    # TODO find the location key
    discard

  let curl = libcurl.easy_init()

  baseurl = CTX.cfgFile.getSectionValue("AW", "baseurl", "http://dataservice.accuweather.com/currentconditions/v1/")
  baseurl.add($loc_key)
  baseurl.add("?apikey=")
  baseurl.add(CTX.cfgFile.getSectionValue("AW", "apikey", "none"))
  baseurl.add("&language=en&details=true")
  url.add(baseurl)
  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)
  debugmsg fmt"The url is {url}"
  # fetch the current conditions
  ret = curl.easy_perform()
  if ret == E_OK:
    try:
      this.currentResult = json.parseJson(webData[])
    except:
      C.LOG_ERR(fmt"CC: readFromApi(): Exception {getCurrentExceptionMsg()}")
      res = -1
  else:
    C.LOG_ERR(fmt"CC: readFromApi(): curl.easy_perform() returned error {ret}")
    res = -1

  # build forecast url
  forecasturl = CTX.cfgFile.getSectionValue("AW", "fc_baseurl", "http://dataservice.accuweather.com/forecasts/v1/daily/5day/")
  forecasturl.add($loc_key)
  forecasturl.add("?apikey=")
  forecasturl.add(CTX.cfgFile.getSectionValue("AW", "apikey", "none"))
  forecasturl.add("&language=en&details=true&metric=true")

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

method populateSnapshot*(this: DataHandler_AW): bool =
  var n, f: json.JsonNode

  #try:
  n = this.currentResult[0]
  f = this.forecastResult["DailyForecasts"][0]

  debugmsg "setup done"
  this.p.valid = true
  this.p.api = "AW"

  # times
  this.p.sunriseTime = times.fromUnix(f["Sun"]["EpochRise"].getInt())
  this.p.sunsetTime = times.fromUnix(f["Sun"]["EpochSet"].getInt())
  this.p.timeRecorded = times.fromUnix(n["EpochTime"].getInt())
  this.p.timeRecordedAsText = times.format(this.p.timeRecorded, "HH:mm", times.local())
  this.p.sunsetTimeAsString = times.format(this.p.sunsetTime, "HH:mm", times.local())
  this.p.sunriseTimeAsString = times.format(this.p.sunriseTime, "HH:mm", times.local())

  this.p.is_day = n["IsDayTime"].getBool()
  this.p.weatherCode = n["WeatherIcon"].getInt()
  this.p.weatherSymbol = this.getIcon(is_day = this.p.is_day)
  this.p.timeZone = CTX.cfgFile.getSectionValue("AW", "timezone", "Europe/Vienna")
  this.p.conditionAsString = n["WeatherText"].getStr()

  # temps
  this.p.temperature =          n["Temperature"]["Metric"]["Value"].getFloat()
  this.p.temperatureApparent =  n["RealFeelTemperature"]["Metric"]["Value"].getFloat()
  this.p.temperatureMax =       f["Temperature"]["Maximum"]["Value"].getFloat()
  this.p.temperatureMin =       f["Temperature"]["Minimum"]["Value"].getFloat()

  # wind stuff
  this.p.windSpeed =      this.convertWindspeed(n["Wind"]["Speed"]["Metric"]["Value"].getFloat() / 3.6)
  this.p.windGust =       this.convertWindspeed(n["WindGust"]["Speed"]["Metric"]["Value"].getFloat() / 3.6)
  this.p.windDirection =  n["Wind"]["Direction"]["Degrees"].getInt()
  this.p.windBearing =    this.degToBearing(this.p.windDirection)
  this.p.windUnit =       CTX.cfg.wind_unit

  this.p.visibility = this.convertVis(n["Visibility"]["Metric"]["Value"].getFloat() * 1000)

  this.p.pressureSeaLevel = this.convertPressure(n["Pressure"]["Metric"]["Value"].getFloat())
  this.p.humidity = n["RelativeHumidity"].getFloat()

  # daily forecasts, 3 days. TODO: make it customizable?
  let base = this.forecastResult["DailyForecasts"]
  for i in countup(0, 2):
    this.daily[i].code = this.getIcon(base[i + 1]["Day"]["Icon"].getInt(), true)
    this.daily[i].temperatureMin = base[i + 1]["Temperature"]["Minimum"]["Value"].getFloat()
    this.daily[i].temperatureMax = base[i + 1]["Temperature"]["Maximum"]["Value"].getFloat()
    this.daily[i].weekDay = times.format(times.fromUnix(base[i + 1]["EpochDate"].getInt()), "ddd", times.local())

  this.p.haveUVI = true
  this.p.uvIndex = n["UVIndex"].getFloat()

  this.p.dewPoint = n["DewPoint"]["Metric"]["Value"].getFloat()
  this.p.precipitationProbability = f["Day"]["PrecipitationProbability"].getFloat()
  this.p.precipitationIntensity = n["Precip1hr"]["Metric"]["Value"].getFloat()
  if n["HasPrecipitation"].getBool():
    this.p.precipitationType = 0
    this.p.precipitationTypeAsString = n["PrecipitationType"].getStr()
  else:
    this.p.precipitationType = 0
    this.p.precipitationTypeAsString = ""

  this.p.cloudCover = n["CloudCover"].getFloat()
  this.p.cloudBase = 0
  this.p.cloudCeiling = n["Ceiling"]["Metric"]["Value"].getFloat()
  this.p.apiId = this.api_id
  #except:
  #  C.LOG_ERR(fmt"CC: populateSnapshot() - exception: {getCurrentExceptionMsg()}")
  #  return false
  return true
