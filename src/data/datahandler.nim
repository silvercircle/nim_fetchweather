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

import std/[json, times, os, strformat, parsecfg]
import "../context"
import "../utils/utils"
import "../utils/stats" as S

var wind_directions*:  array[16, string] = [
      "N", "NNE", "NE",
      "ENE", "E", "ESE",
      "SE", "SSE", "S",
      "SSW", "SW", "WSW",
      "W", "WNW", "NW",
      "NNW"]

type DailyForecast* = object
  code*:                                              char
  temperatureMin*, temperatureMax*:                   float
  weekDay*:                                           string
  pop*:                                               float

type DataPoint* = object
  api*:                                               string
  is_day*, valid*:                                    bool
  timeRecorded*, sunsetTime*, sunriseTime*:           Time
  timeRecordedAsText*:                                string
  timeZone*:                                          string
  weatherCode*:                                       int
  weatherSymbol*:                                     char
  temperature*, temperatureApparent*,
    temperatureMin*, temperatureMax*:                 float
  visibility*:                                        float # this must be in km (some providers use meters)
  windSpeed*, windGust*:                              float
  cloudCover*:                                        float
  cloudBase*, cloudCeiling*:                          float
  moonPhase*:                                         int
  moonPhaseAsString*:                                 string
  windDirection*:                                     int
  precipitationType*:                                 int
  precipitationTypeAsString*:                         string
  precipitationProbability*, precipitationIntensity*: float
  pressureSeaLevel*, humidity*, dewPoint*:            float
  sunsetTimeAsString*, sunriseTimeAsString*,
    windBearing*, windUnit*:                          string
  conditionAsString*:                                 string
  uvIndex*:                                           float
  haveUVI*:                                           bool
  apiId*:                                             string

type DataHandler* = ref object of RootObj
  p*:               DataPoint
  daily*:           array[3, DailyForecast]
  currentResult*,   forecastResult*: JsonNode
  stats*:           APIStats

# abstract methods, must be overridden

method populateSnapshot*      (this: DataHandler): bool {.base.} = true
method readFromApi*           (this: DataHandler): int {.base.} = -1
method getCondition*          (this: DataHandler, c: int): string {.base.} = "Clear"
method checkRawDataValidity*  (this: DataHandler): bool {.base.} = false
method getAPIId*              (this: DataHandler): string {.base.} = ""
method getIcon                (this: DataHandler): char {.base.} = 'c'
method getIcon                (this: DataHandler, code: int = 100, is_day: bool = true): char {.base.} = 'c'
method getIcon                (this: DataHandler, code: string = ""): char {.base.} = 'c'

method construct*(this: DataHandler): DataHandler {.base.} =
  echo "constructing a datahandler"
  return this

# write current and forcast json to cache files. The prefix is basically
# the shortcode for the API in use. Example: OWM, CC are valid prefixes for
# OpenWeatherMap and ClimaCell
method writeCache*(this: DataHandler, prefix: string): void {.base.} =
  let file_current = os.joinPath(CTX.dataDirPath, prefix & "_current.json")
  let file_forecast = os.joinPath(CTX.dataDirPath, prefix & "_forecast.json")
  writeFile(file_current, $this.currentResult)
  writeFile(file_forecast, $this.forecastResult)

method readFromCache*(this: DataHandler, prefix: string): int {.base.} =
  let file_current = os.joinPath(CTX.dataDirPath, prefix & "_current.json")
  let file_forecast = os.joinPath(CTX.dataDirPath, prefix & "_forecast.json")
  debugmsg fmt"Reading from Cache: {file_current} and {file_forecast}"
  if os.fileExists(file_current) and os.fileExists(file_forecast):
    var
      current, forecast: string
    current = readFile(file_current)
    forecast = readFile(file_forecast)
    try:
      this.currentResult = json.parseJson(current)
      this.forecastResult = json.parseJson(forecast)
      if this.checkRawDataValidity():
        debugmsg fmt"Validity check passed for {prefix}"
        return 0
      else:
        return -1
    except:
      context.LOG_ERR(fmt"readFromCache(): ({prefix}) Exception {getCurrentExceptionMsg()}")
  else:
    context.LOG_ERR(fmt"Attempt to read from Cache: {file_current} and {file_forecast}. Error: file(s) don't exist")
    return -1
  return 0

# read basic stats, update last timestamp, reset daily requests when necessary
method updateStats*(this: DataHandler, api:string): void {.base.} =
  # read and update stats
  let now = times.now()

  S.readStats(this.stats, api)
  let old_time = times.parse(CTX.statsFile.getSectionValue(api, "last_request",
                                 $now), "yyyy-MM-dd'T'HH:mm:sszzz", times.local())
  this.stats.last_request = times.now()
  CTX.statsFile.setSectionKey(api, "last_request", $this.stats.last_request)

  if old_time.weekday() != now.weekday():
    this.stats.requests_today = 0

method writeStats*(this: DataHandler, api: string): void {.base.} =
  CTX.statsFile.setSectionKey(api, "RequestsAll", $this.stats.requests_all)
  CTX.statsFile.setSectionKey(api, "RequestsToday", $this.stats.requests_today)
  CTX.statsFile.setSectionKey(api, "RequestsFailed", $this.stats.requests_failed)

method convertPressure*(this: DataHandler, hPa: float = 1013): float {.base.} =
  if CTX.cfg.pressure_unit == "inhg": hPa / 33.863886666667 else: hPa

method convertWindspeed*(this: DataHandler, speed: float = 0): float {.base.} =
  let unit = CTX.cfg.wind_unit
  if unit == "km/h":
    return speed * 3.6;
  elif unit == "mph":
    return speed * 2.237;
  elif unit == "kts":
    return speed * 1.944;
  else:
    return speed;

# vis: must be in meters by default, but can be in km or miles if indicated via
# source_unit
method convertVis*(this: DataHandler, vis: float, source_unit: string = "m"): float {.base.} =
  case source_unit:
    of "km":
      return (if CTX.cfg.vis_unit == "mi": vis / 1.609 else: vis)
    of "mi":
      return (if CTX.cfg.vis_unit == "mi": vis else: vis * 1.609)
    else:   # assuming source = in meters
      return (if CTX.cfg.vis_unit == "mi": vis / 1000 / 1.609 else : vis / 1000)

# convert a wind direction (in degrees) into a compass sector
method degToBearing*(this: DataHandler, wind_direction: int = 0): string {.base.} =
  var wd: int = (if wind_direction > 360 or wind_direction < 0: 0 else: wind_direction)
  let val = wd.float / 22.5 + 0.5
  return wind_directions[val.uint mod 16]

method convertTemperature(this: DataHandler, val: float): float {.base.} =
  if not CTX.cfg.metric:
    return (val * (9.0 / 5.0)) + 32.0;
  return val

method outputTemperature(this: DataHandler, stream: File, val: float, addUnit: bool, format: cstring = ""): void {.base.} =
  # char unit[5] = "\xc2\xB0X";    // UTF-8!! c2b0 is the utf8 sequence for ° (degree symbol)

  var
    unit: string = if CTX.cfg.metric: "°C" else: "°F"

  var res: float = this.convertTemperature(val)
  discard fprintf(stream, "%.1f%s\n", res, (if addUnit: unit else: ""))


method doOutput*(this: DataHandler, stream: File): void {.base.} =
  discard fprintf(stream, "** Begin output **\n");
  discard fprintf(stream, "%c\n", this.p.weatherSymbol);
  this.outputTemperature(stream, this.p.temperature, true)

  for i in countup(0, 2):
    discard fprintf(stream, "%c\n", this.daily[i].code)
    this.outputTemperature(stream, this.daily[i].temperatureMin, false)
    this.outputTemperature(stream, this.daily[i].temperatureMax, false)
    discard fprintf(stream, "%s\n", this.daily[i].weekDay)

  this.outputTemperature(stream, this.p.temperatureApparent, true)
  this.outputTemperature(stream, this.p.dewPoint, true)

  discard fprintf(stream, "Humidity: %.1f\n", this.p.humidity);                                         # 18
  discard fprintf(stream, (if CTX.cfg.pressure_unit == "hPa": "%.0f hPa\n" else: "%.2f InHg\n"),        # 19
           this.p.pressureSeaLevel)

  discard fprintf(stream, "%.1f %s\n", this.p.windSpeed, CTX.cfg.wind_unit)                             # 20

  if this.p.precipitationIntensity > 0:
    discard fprintf(stream, "%s (%.1fmm/1h)\n", this.p.precipitationTypeAsString,
            this.p.precipitationIntensity);                                                             # 21
  else:
    discard fprintf(stream, "PoP: %.0f%%\n", this.p.precipitationProbability);                          # 21

  discard fprintf(stream, "%.1f %s\n", this.p.visibility, CTX.cfg.vis_unit)                             # 22
  discard fprintf(stream, "%s\n", this.p.sunriseTimeAsString)                                           # 23
  discard fprintf(stream, "%s\n", this.p.sunsetTimeAsString)                                            # 24
  discard fprintf(stream, "%s\n", this.p.windBearing)                                                   # 25
  discard fprintf(stream, "%s\n", this.p.timeRecordedAsText)                                            # 26

  discard fprintf(stream, "%s", this.p.conditionAsString)                                               # 27
  if this.p.cloudCover > 0:
    discard fprintf(stream, " (%.0f%%)\n", this.p.cloudCover)                                      # 28
  else:
    discard fprintf(stream, "\n")

  discard fprintf(stream, "%s\n", this.p.timeZone)                                                      # 29
  this.outputTemperature(stream, this.p.temperatureMin, true)
  this.outputTemperature(stream, this.p.temperatureMax, true)

  if this.p.haveUVI:
    discard fprintf(stream, "UV: %.1f\n", this.p.uvIndex);
  else:
    discard fprintf(stream, " \n")

  discard fprintf(stream, "** end data **\n")
  discard fprintf(stream, "%.0f (Clouds)\n", this.p.cloudCover)
  discard fprintf(stream, "%.0f (Cloudbase)\n", this.p.cloudBase)
  discard fprintf(stream, "%.0f (Cloudceil)\n", this.p.cloudCeiling)
  discard fprintf(stream, "%d (Moon)\n", this.p.moonPhase)
  discard fprintf(stream, "%s\n", this.p.apiId)