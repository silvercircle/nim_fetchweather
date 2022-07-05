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

import std/[os, logging, times, parsecfg]

template debugmsg*(data: untyped) =
  when not defined(release):
    echo "DEBUG: " & data

# application context as singleton
# only one object of type Context is allowed to exist

# the class itself is private so no other instances can be created
type Options = object
  dryRun*: bool
  inited*: string
  apikey*: string

# this initializes our configuration object
# it sets defaults and parses the command line options

proc initOptions(): Options =
  var o: Options
  o = Options(
    dryRun: false,
    inited: "yes",
    apikey: "none")
  return o

type Context* = ref object
  id*: int64
  timestamp: times.DateTime
  # cfg_saved are the options from the ini file
  # cfg are the effective options that are overriden by command line switches
  cfg_saved*, cfg*: Options
  cfgFile*: parsecfg.Config

  # directories
  cfgDirPath, cfgFilePath, dataDirPath: string
  stdLogger*: logging.ConsoleLogger

# this is the instance, it's public and will be initialized automatically
var CTX*: Context = Context(id: 111, timestamp: times.now())

proc greeter*(this: Context): void =
  echo "The context ID is: " & $this.id
  echo "I was created at: " & $this.timestamp.format("HH:mm:ss")
  echo "CFG: ", this.cfg, "\n", "CFG_saved: ", this.cfg_saved

# populate our config file object with defaults
proc setCfgDefaults(this: Context): void =
  this.cfgFile = newConfig()
  this.cfgFile.setSectionKey("General", "firstRun", "yes")
  this.cfgFile.setSectionKey("Auth", "username", "alex")
  this.cfgFile.setSectionKey("Auth", "pass", "foo")
  this.cfgFile.setSectionKey("CC", "apikey", "none")
  this.cfgFile.setSectionKey("OWM", "apikey", "none")
  this.cfgFile.setSectionKey("CC", "loc", "none")
  this.cfgFile.setSectionKey("OWM", "loc", "none")

# init the config, read config file (or create one), handle default
# values
proc init*(this: Context): void =
  this.stdLogger = logging.newConsoleLogger()
  logging.addHandler(this.stdLogger)
  setCfgDefaults(this)
  let cfgDir = os.getConfigDir()
  var dataDir = os.getHomeDir()
  dataDir = os.joinPath(dataDir, ".local", "share", "nim_fetchweather")
  debugmsg "The data dir is: " & dataDir

  try:
    if os.existsOrCreateDir(dataDir):
      this.dataDirPath = dataDir
  except OSError as e:
    echo "The data dir cannot be found or created. This is an urecoverable error"
    echo e.msg
    system.quit(-1)

  this.cfgDirPath = os.joinPath(cfgDir, "nim_fetchweather")
  this.cfgFilePath = os.joinPath(this.cfgDirPath, "nim_fetchweatherrc")

  # read the existing config (if we have one)
  if os.fileExists(this.cfgFilePath):
    this.cfgFile = loadConfig(this.cfgFilePath)

  # create a new config file if none exists.
  try:
    if os.existsOrCreateDir(this.cfgDirPath):
      # debug "The config file is at " & this.cfgFilePath
      if not os.fileExists(this.cfgFilePath):
        let f = system.open(this.cfgFilePath, fmReadWrite)
        defer: f.close()
      this.cfgFile.writeConfig(this.cfgFilePath)
  except OSError as e:
    echo "The config path is invalid or cannot be created (Permission problem?)"
    echo e.msg
    system.quit(-1)

  # echo this.cfgFile
  this.cfg = initOptions()
  this.cfg_saved = this.cfg
  this.cfg_saved.dryRun = true
