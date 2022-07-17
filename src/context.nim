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

import std/[os, logging, times, parsecfg, strformat]

let g_version* = "0.9.1"

type apiconfig = object
  shortname:    string        # the shortcode
  fullname:     string        # full name of the api, currently not used anywhere
  baseurl:      string        # the base url for the standard current condition request
  baseurl_fc:   string        # the base url for the forecast request. This is optional for some
                              # apis

var
  apiconfigs:    array[4, apiconfig] = [
    apiconfig(shortname:"CC", fullname: "Climacell",
              baseurl: "https://data.climacell.co/v4/timelines?&apikey=",
              baseurl_fc: "https://data.climacell.co/v4/timelines?&apikey="),

    apiconfig(shortname:"VC", fullname: "Visual Crossing",
              baseurl: "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/___LOC___?unitGroup=metric&include=events,days,hours,alerts,current&iconSet=icons2&contentType=json&key=",
              baseurl_fc: "none"),

    apiconfig(shortname:"AW", fullname: "AccuWeather",
              baseurl: "http://dataservice.accuweather.com/currentconditions/v1/",
              baseurl_fc: "http://dataservice.accuweather.com/forecasts/v1/daily/5day/"),

    apiconfig(shortname:"OWM", fullname: "Open Weather Map",
              baseurl: "http://api.openweathermap.org/data/2.5/onecall?appid=",
              baseurl_fc: "none")
  ]

template debugmsg*(data: untyped) =
  when not defined(release):
    echo "DEBUG: " & data

# application context as singleton
# only one object of type Context is allowed to exist

# the class itself is private so no other instances can be created
type Options = object
  dryRun*:        bool
  inited*:        string
  apikey*:        string
  loc*:           string
  timezone*:      string
  wind_unit*:     string
  vis_unit*:      string
  pressure_unit*: string
  metric*:        bool
  api*:           string
  silent*:        bool      # command line option, no output
  no_db*:         bool      # do not record to db
  dumpfile*:      string    # dump output to file
  statsfile*:     string
  do_dump*:       bool      # we want a dump?
  cached*:        bool      # skip online, use cached data
  fallback*:      bool      # fall back to cache when online fails

# this initializes our configuration object
# it sets defaults and parses the command line options

proc initOptions(): Options =
  var o: Options
  o = Options(
    dryRun: false,
    inited: "yes",
    apikey: "none",
    loc: "none",
    timezone: "none",
    wind_unit: "m/s",
    vis_unit: "km",
    pressure_unit: "hPa",
    metric: true,
    api:  "OWM",
    silent: false,
    no_db:  false,
    dumpfile: "",
    do_dump: false,
    cached: false)
  return o

type Context* = ref object
  id*: int64
  timestamp: times.DateTime
  # cfg_saved are the options from the ini file
  # cfg are the effective options that are overriden by command line switches
  cfg_saved*, cfg*: Options
  cfgFile*, statsFile*: parsecfg.Config

  # directories
  cfgDirPath, cfgFilePath, logFilePath, dataDirPath*: string
  stdLogger*: logging.FileLogger

# this is the instance, it's public and will be initialized automatically
var CTX*: Context = Context(id: 111, timestamp: times.now())

template LOG_INFO*(data: untyped) =
  CTX.stdLogger.log(logging.lvlInfo, data)
  when defined(debug):
    debugmsg data

template LOG_ERR*(data: untyped) =
  CTX.stdLogger.log(logging.lvlError, data)
  when defined(debug):
    debugmsg data

template LOG_FATAL*(data: untyped) =
  CTX.stdLogger.log(logging.lvlFatal, data)
  when defined(debug):
    debugmsg data

method getCfgFilePath*(this: Context): string {.base.} =
  return this.cfgFilePath

method getDataDirPath*(this: Context): string {.base.} =
  return this.dataDirPath

# populate our config file object with defaults
method setCfgDefaults(this: Context): void {.base.} =
  this.cfgFile = newConfig()
  this.cfgFile.setSectionKey("General", "firstRun", "yes")
  this.cfgFile.setSectionKey("General", "metric", "true")
  this.cfgFile.setSectionKey("Auth", "username", "alex")
  this.cfgFile.setSectionKey("Auth", "pass", "foo")
  this.cfgFile.setSectionKey("CC", "apikey", "none")
  this.cfgFile.setSectionKey("OWM", "apikey", "none")
  this.cfgFile.setSectionKey("CC", "loc", "none")
  this.cfgFile.setSectionKey("OWM", "loc", "none")

  # units
  this.cfgFile.setSectionKey("Units", "pressure", "hPa");
  this.cfgFile.setSectionKey("Units", "windspeed", "km/h");
  this.cfgFile.setSectionKey("Units", "metric", "true");

  # apiconfigs
  for a in apiconfigs:
    this.cfgFile.setSectionKey(a.shortname, "fullname", a.fullname)
    this.cfgFile.setSectionKey(a.shortname, "baseurl", a.baseurl)
    this.cfgFile.setSectionKey(a.shortname, "fc_baseurl", a.baseurl_fc)
    this.cfgFile.setSectionKey(a.shortname, "apikey", "none")
    this.cfgFile.setSectionKey(a.shortname, "loc", "none")


# init the config, read config file (or create one), handle default
# values
method init*(this: Context): void {.base.} =
  setCfgDefaults(this)
  let cfgDir = os.getConfigDir()
  var dataDir = os.getHomeDir()
  dataDir = os.joinPath(dataDir, ".local", "share", "nim_fetchweather")

  try:
    if os.existsOrCreateDir(dataDir):
      this.dataDirPath = dataDir
  except OSError as e:
    echo "The data dir cannot be found or created. This is an urecoverable error"
    echo e.msg
    system.quit(-1)

  this.logfilePath = os.joinPath(dataDir, "log.log")
  this.stdLogger = logging.newFileLogger(this.logFilePath)
  logging.addHandler(this.stdLogger)
  this.stdLogger.fmtStr = "$datetime: $levelname - "
  this.stdLogger.log(logging.lvlInfo, "------------------ Logger created ------------------ ")
  this.cfgDirPath = os.joinPath(cfgDir, "nim_fetchweather")
  this.cfgFilePath = os.joinPath(this.cfgDirPath, "nim_fetchweatherrc")

  # read the existing config (if we have one)
  if os.fileExists(this.cfgFilePath):
    this.cfgFile = loadConfig(this.cfgFilePath)
  else:
    # create a new config file if none exists.
    try:
      if os.existsOrCreateDir(this.cfgDirPath):
        # debug "The config file is at " & this.cfgFilePath
        if not os.fileExists(this.cfgFilePath):
          let f = system.open(this.cfgFilePath, fmReadWrite)
          defer: f.close()
          this.cfgFile.writeConfig(this.cfgFilePath)
    except OSError as e:
      LOG_ERR fmt"The config path is invalid or cannot be created (Permission problem?)"
      echo e.msg
      system.quit(-1)

  # echo this.cfgFile
  this.cfg = initOptions()
  this.cfg.metric = (if $this.cfgFile.getSectionValue("units", "metric", "true") == "true": true else: false)
  this.cfg.wind_unit = $this.cfgFile.getSectionValue("units", "windspeed", "m/s")
  this.cfg.vis_unit = $this.cfgFile.getSectionValue("units", "visibility", "km")
  this.cfg.pressure_unit = $this.cfgFile.getSectionValue("units", "pressure", "hPa")
  this.cfg.api = $this.cfgFile.getSectionValue("General", "api", "OWM")
  # set a default for the dump file this can be overridden on the command line
  this.cfg.dumpfile = os.joinPath(this.dataDirPath, "dump_" & $times.getTime())
  this.cfg.statsfile = os.joinPath(this.dataDirPath, "stats.ini")
  if os.fileExists(this.cfg.statsfile):
    this.statsFile = parsecfg.loadConfig(this.cfg.statsfile)
  else:
    this.statsFile = parsecfg.newConfig()
  debugmsg fmt"The dump file path is: {this.cfg.dumpfile}"
  this.cfg_saved = this.cfg
  this.cfg_saved.dryRun = true

method finalize*(this: Context): void {.base.} =
  this.statsFile.writeConfig(this.cfg.statsfile)
