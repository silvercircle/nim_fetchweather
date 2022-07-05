import std/json
import context

proc json_test*(): void =
  var bar: JsonNode
  bar = json.parseJson("""{"numeric": 2.0, "string": "arsch"}""")
  echo $bar["numeric"] & " and " & $bar["string"]

  let file: string = readFile("/home/alex/.local/share/fetchweather/cache/CC.current.json")

  var current: JsonNode = json.parseJson(file)
  echo "The start time is: " & $current["data"]["timelines"][0]["startTime"]
  echo CTX.id