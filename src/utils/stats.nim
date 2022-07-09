import std/[times, parsecfg, strutils]
import "../context" as C

type APIStats* = object
  requests_all*:        int
  requests_today*:      int
  requests_failed*:     int
  last_request*:        DateTime
  last_failed*:         DateTime

type Stats = ref object of RootObj

proc readStats*(s: var APIStats, api: string = "OWM"): void =
  s.requests_all = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsAll", "0"))
  s.requests_today = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsToday", "0"))
  s.requests_failed = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsFailed", "0"))
  return
