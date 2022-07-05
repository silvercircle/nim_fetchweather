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
