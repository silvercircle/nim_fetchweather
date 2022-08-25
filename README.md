# Weather fetching app

## this is work in progress, probably not very useful yet.

This is the Nim Version of my old darksky Rust app that fetches JSON weather data from the service API. For years, I've been using darksky for this purpose, but since it's been acquired by Apple and will be closing at the end of 2021, a new provider must be used. I decided to give [ClimaCell](https://climacell.co) a try. Unfortunately, their data format is quite a bit different from Darksky's, so some work to adjust was necessary.

This application will be able to use multiple APIs and normalize the data into a common format. Planned are support for ClimaCell (mostly done), OpenWeatherMap, VisualCrossing and maybe others.

Right now, it can fetch weather from ClimaCell, AccuWeather, Open Weather Map and Visual Crossing API.

## Built instructions

Basically, everything is included. You build with `nimble debug` or `nimble release`.

Please take not of the configuration file `nim_fetchweatherrc`. You need to edit it with your data (api Keys, location, timezones) and place it into `~/.config/nim_fetchweather`.
## Acknowledgements

This is free software governed by the MIT License. It uses the following 3rd party open source libraries and/or components:

* Araq/curl, a curl implementation for Nim
