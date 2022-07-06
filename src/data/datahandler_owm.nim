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


import datahandler
import std/[json, parsecfg, tables, logging, strformat]
import libcurl
import "../utils/utils" as utils
import "../context"
import times

type DataHandler_OWM* = ref object of DataHandler

method readFromAPI*(this: DataHandler_OWM): int =
  var
    baseurl, url: string
    ret: Code

  let webData: ref string = new string

  let curl = libcurl.easy_init()

  baseurl = CTX.cfgFile.getSectionValue("OWM", "baseurl", "http://api.openweathermap.org/data/2.5/onecall?appid=")
  baseurl.add(CTX.cfgFile.getSectionValue("OWM", "apikey", "none"))
  baseurl.add("&lat=" & $CTX.cfgFile.getSectionValue("OWM", "lat", "0,0"))
  baseurl.add("&lon=" & $CTX.cfgFile.getSectionValue("OWM", "lon", "0,0"))
  # baseurl.add("&timezone=" & $CTX.cfgFile.getSectionValue("CC", "timezone","Europe/Vienna"))
  url.add(baseurl)
  url.add("&exclude=minutely&units=metric");

  debugmsg "THE URL IS  " & url

  discard curl.easy_setopt(OPT_USERAGENT, "Mozilla/5.0")
  discard curl.easy_setopt(OPT_HTTPGET, 1)
  discard curl.easy_setopt(OPT_WRITEDATA, webData)
  discard curl.easy_setopt(OPT_WRITEFUNCTION, utils.curlWriteFn)
  discard curl.easy_setopt(OPT_URL, url)

  # fetch the current conditions. For OWM, this includes all the forecast
  ret = curl.easy_perform()
  if ret == E_OK:
    try:
      this.currentResult = json.parseJson(webData[])
      this.currentResult["data"] = %* {"status": {"code": "success"}}
      this.forecastResult = json.parseJson """{"data": {"status": {"code": "success"}}}"""
    except:
      echo "EXCEPTION"
      this.currentResult["data"] = %* {"status": {"code": "failure"}}
      this.forecastResult = json.parseJson """{"data": {"status": {"code": "failure"}}}"""
  else:
    return -1

method populateSnapshot*(this: DataHandler_OWM): bool =
  var n, f: json.JsonNode
  context.LOG_INFO(fmt"OWM:populateSnapshot()")

  n = this.currentResult["current"]
  f = this.currentResult["daily"][0]
  this.p.valid = true

  this.p.sunriseTime = times.fromUnix(n["sunrise"].getInt())
  this.p.sunsetTime = times.fromUnix(n["sunset"].getInt())
  this.p.timeRecorded = times.getTime()
  this.p.timeRecordedAsText = times.format(this.p.timeRecorded, "HH:MM", times.local())
  this.p.is_day = (if this.p.timeRecorded > this.p.sunriseTime and this.p.timeRecorded < this.p.sunsetTime: true else: false)
  this.p.weatherCode = n["weather"][0]["id"].getInt()
  this.p.timeZone = CTX.cfgFile.getSectionValue("OWM", "timezone")
  this.p.conditionAsString = n["weather"][0]["main"].getStr()

  echo this.p
  try:
    echo n["dew_point"]
  except:
    echo getCurrentExceptionMsg()
    return false

  return true
