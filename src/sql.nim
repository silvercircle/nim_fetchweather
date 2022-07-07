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

{.warning[CStringConv]: off.}
{.warning[LockLevel]: off.}

import std/db_sqlite as sql
import std/[times, strformat]
import data/datahandler
import os
import context as C

proc writeSQL*(data: var DataHandler): void =
  var
    db: sql.DbConn
    d: ptr DataPoint = data.p.addr

  when defined(debug):
    let sqlite_filename = os.joinPath(CTX.dataDirPath, "historydebug.sqlite3")
    debugmsg fmt"writing to debug Database"
  else:
    let sqlite_filename = os.joinPath(CTX.dataDirPath, "history.sqlite3")
  debugmsg "The sql file name is: " & sqlite_filename

#  when defined(debug):
#    debugmsg "Debug mode, skipping db operation"
#    return

  db = sql.open(sqlite_filename, "", "", "")

  db.exec(sql"""CREATE TABLE IF NOT EXISTS history
      (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER DEFAULT 0,
          summary TEXT NOT NULL DEFAULT 'unknown',
          icon TEXT NOT NULL DEFAULT 'unknown',
          temperature REAL NOT NULL DEFAULT 0.0,
          feelslike REAL NOT NULL DEFAULT 0.0,
          dewpoint REAL DEFAULT 0.0,
          windbearing INTEGER DEFAULT 0,
          windspeed REAL DEFAULT 0.0,
          windgust REAL DEFAULT 0.0,
          humidity REAL DEFAULT 0.0,
          visibility REAL DEFAULT 0.0,
          pressure REAL DEFAULT 1013.0,
          precip_probability REAL DEFAULT 0.0,
          precip_intensity REAL DEFAULT 0.0,
          precip_type TEXT DEFAULT 'none',
          cloudCover REAL DEFAULT 0.0,
          cloudBase REAL DEFAULT 0.0,
          cloudCeiling REAL DEFAULT 0.0,
          moonPhase INTEGER DEFAULT 0,
          uvindex INTEGER DEFAULT 0,
          sunrise INTEGER DEFAULT 0,
          sunset INTEGER DEFAULT 0,
          tempMax REAL DEFAULT 0.0,
          tempMin REAL DEFAULT 0.0
      )"""
    )
  try:
    db.exec(sql"BEGIN")
    let res = db.tryExec(sql"""INSERT INTO history(timestamp, summary, icon, temperature,
                        feelslike, dewpoint, windbearing, windspeed,
                        windgust, humidity, visibility, pressure,
                        precip_probability, precip_intensity, precip_type,
                        uvindex, sunrise, sunset, cloudBase, cloudCover, cloudCeiling, moonPhase,
                        tempMin, tempMax) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                        d.timeRecorded.toUnix(), d.conditionAsString, d.weatherSymbol,
                        d.temperature, d.temperatureApparent, d.dewPoint, d.windDirection,
                        d.windSpeed, d.windGust, d.humidity, d.visibility, d.pressureSeaLevel,
                        d.precipitationProbability, d.precipitationIntensity, d.precipitationTypeAsString,
                        d.uvIndex.int, d.sunriseTime.toUnix(), d.sunsetTime.toUnix(), d.cloudBase,
                        d.cloudCover, d.cloudCeiling, d.moonPhase, d.temperatureMin,
                        d.temperatureMax)
    if not res:
      debugmsg fmt"failed insert (code = {res})"
      C.LOG_ERR(fmt"writeSql: insert failed with code {res}")
      dbError(db)
    else:
      debugmsg fmt"tryExec() successfull ret = {res}"

    db.exec(sql"COMMIT")
  except:
    debugmsg fmt"Database Exception while inserting, {getCurrentExceptionMsg()}"
    C.LOG_ERR(fmt"Database exception while inserting, {getCurrentExceptionMsg()}")

  db.close()
