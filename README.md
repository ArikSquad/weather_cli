# Weather CLI

An Elixir command-line app that shows current weather with terminal output.

## Requirements

- Elixir 1.19+

## Setup

1. Install dependencies:

   ```bash
   mix deps.get
   ```

2. Configure your API key in `.env`:

   ```env
   OPENWEATHER_API_KEY=your_openweathermap_api_key_here
   ```

## Run

```bash
mix run -e 'WeatherCli.main([])'
```

You can also build an executable:

```bash
mix escript.build
./weather_cli --help
```

## Usage

```bash
./weather_cli --auto
./weather_cli --city "Bengaluru"
./weather_cli
```

If no option is provided, the CLI asks whether to auto-detect location or enter a city manually.
