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

# this initializes our configuration object
# it sets defaults and parses the command line options

proc initOptions(): Options =
  var o: Options
  o = Options(
    dryRun: false,
    inited: "yes")
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

# init the config, read config file (or create one), handle default
# values
proc init*(this: Context): void =
  this.stdLogger = logging.newConsoleLogger()
  logging.addHandler(this.stdLogger)
  setCfgDefaults(this)
  let cfgDir = os.getConfigDir()
  var dataDir = os.getHomeDir()
  dataDir = os.joinPath(dataDir, ".local", "share", "nimtest")
  debugmsg "The data dir is: " & dataDir

  try:
    if os.existsOrCreateDir(dataDir):
      this.dataDirPath = dataDir
  except OSError as e:
    echo "The data dir cannot be found or created. This is an urecoverable error"
    echo e.msg
    system.quit(-1)

  this.cfgDirPath = os.joinPath(cfgDir, "nimtest")
  this.cfgFilePath = os.joinPath(this.cfgDirPath, "nimtestrc")

  # read the existing config (if we have one)
  if os.fileExists(this.cfgFilePath):
    this.cfgFile = loadConfig(this.cfgFilePath)

  # create a new config file if none exists.
  try:
    if os.existsOrCreateDir(this.cfgDirPath):
      debug "The config file is at " & this.cfgFilePath
      if not os.fileExists(this.cfgFilePath):
        let f = system.open(this.cfgFilePath, fmReadWrite)
        defer: f.close()
      this.cfgFile.writeConfig(this.cfgFilePath)
  except OSError as e:
    echo "The config path is invalid or cannot be created (Permission problem?)"
    echo e.msg
    system.quit(-1)

  echo this.cfgFile
  this.cfg = initOptions()
  this.cfg_saved = this.cfg
  this.cfg_saved.dryRun = true
