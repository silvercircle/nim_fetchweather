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

import std/[json, parsecfg, times]
import "../context"
import "../utils/utils"

type DailyForecast* = object
  code:                                               char
  temperatureMin, temperatureMax:                     float
  weekDay:                                            string
  pop:                                                float

type DataPoint* = object
  is_day*, valid*:                                    bool
  timeRecorded*, sunsetTime*, sunriseTime*:           Time
  timeRecordedAsText*:                                string
  timeZone*:                                          string
  weatherCode*:                                       int
  weatherSymbol*:                                     char
  temperature, temperatureApparent,
    temperatureMin, temperatureMax:                   float
  visibility:                                         float # this must be in km (some providers use meters)
  windSpeed, windGust:                                float
  cloudCover:                                         float
  cloudBase, cloudCeiling:                            float
  moonPhase:                                          int
  moonPhaseAsString:                                  string
  windDirection:                                      int
  precipitationType:                                  int
  precipitationTypeAsString:                          string
  precipitationProbability*, precipitationIntensity*: float
  pressureSeaLevel, humidity, dewPoint:               float
  sunsetTimeAsString, sunriseTimeAsString,
    windBearing, windUnit:                            string
  conditionAsString*:                                 string
  uvIndex*:                                           int
  haveUVI*:                                           bool


type DataHandler* = ref object of RootObj
  p*:               DataPoint
  daily:            array[3, DailyForecast]
  currentResult*, forecastResult*: JsonNode


method doOutput*(this: DataHandler): void {.base.} =
  echo "doOutput"
  echo "Is this day?" & $this.p.is_day

method populateSnapshot*(this: DataHandler): bool {.base.} = true
method readFromApi*(this: DataHandler): int {.base.} = -1
method getCondition*(this: DataHandler, c: int): string {.base.} = "Clear"


method convertPressure*(this: DataHandler, hPa: float = 1013): float {.base.} =
  return (if CTX.cfgFile.getSectionValue("units", "pressure", "hPa") == "inhg": hPa / 33.863886666667 else: hPa)

method convertWindspeed*(this: DataHandler, speed: float = 0): float {.base.} =
  let unit = CTX.cfgFile.getSectionValue("units", "windspeed", "m/s")
  if unit == "km/h":
      return speed * 3.6;
  elif unit == "mph":
      return speed * 2.237;
  elif unit == "kts":
      return speed * 1.944;
  else:
      return speed;

# convert a wind direction (in degrees) into a compass sector
method degToBearing*(this: DataHandler, wind_direction: int = 0): string {.base.} =
  var wd: int = (if wind_direction > 360 or wind_direction < 0: 0 else: wind_direction)
  let val = wd.float / 22.5 + 0.5
  return utils.wind_directions[val.uint mod 16]
