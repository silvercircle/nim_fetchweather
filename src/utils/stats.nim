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

# keep some stats on number of requests, last request time and more.
# this is wip, more will probably follow

import std/[times, parsecfg, strutils]
import "../context" as C

# each data handler has its own copy
type APIStats* = object
  requests_all*:        int
  requests_today*:      int
  requests_failed*:     int
  last_request*:        DateTime
  last_failed*:         DateTime

# read the stores values from the stats.ini file.
proc readStats*(s: var APIStats, api: string = "OWM"): void =
  s.requests_all = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsAll", "0"))
  s.requests_today = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsToday", "0"))
  s.requests_failed = parseInt(C.CTX.statsFile.getSectionValue(api, "RequestsFailed", "0"))
  return
