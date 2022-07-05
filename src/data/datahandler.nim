import std/json

type DailyForecast = object
    code:                                           char
    temperatureMin, temperatureMax:                 float
    weekDay:                                        string
    pop:                                            float

type DataPoint = object
  is_day, valid:                                    bool
#  timeRecorded, sunsetTime, sunriseTime:
#  timeRecordedAsText[30];
  timeZone:                                         string
  weatherCode:                                      int
  weatherSymbol:                                    char
  temperature, temperatureApparent,
    temperatureMin, temperatureMax:                 float
  visibility:                                       float # this must be in km (some providers use meters)
  windSpeed, windGust:                              float
  cloudCover:                                       float
  cloudBase, cloudCeiling:                          float
  moonPhase:                                        int
  moonPhaseAsString:                                string
  windDirection:                                    int
  precipitationType:                                int
  precipitationTypeAsString:                        string
  precipitationProbability, precipitationIntensity: float
  pressureSeaLevel, humidity, dewPoint:             float
  sunsetTimeAsString, sunriseTimeAsString,
    windBearing, windUnit:                          string
  conditionAsString:                                string
  uvIndex:                                          int
  haveUVI:                                          bool


type DataHandler* = ref object of RootObj
  p*:       DataPoint
  daily:    array[3, DailyForecast]

  currentResult*, forecastResult*: JsonNode

method doOutput*(this: DataHandler): void {.base.} =
  echo "doOutput"
  echo "Is this day?" & $this.p.is_day

method populateSnapshot*(this: DataHandler): void {.base.} = discard
method readFromApi*(this: DataHandler): int {.base.} = -1
