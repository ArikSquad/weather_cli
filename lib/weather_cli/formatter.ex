defmodule WeatherCli.Formatter do
  @moduledoc """
  Terminal renderer for weather output and errors.
  """

  @spec weather(map()) :: String.t()
  def weather(data) do
    card_block(data)
  end

  @spec card_block(map()) :: String.t()
  defp card_block(data) do
    title = "#{data.city}, #{data.country}"
    updated = now_utc()
    icon = weather_icon(data.description)
    desc = capitalize(data.description)
    temp_c = data.temperature_c
    temp_f = celsius_to_f(temp_c)
    feels = data.feels_like_c
    show_f = Map.get(data, :show_fahrenheit, false)
    accent = temp_color(temp_c)

    temp_label = accent.(format_num(temp_c) <> "°C")
    f_part = if(show_f, do: "  (" <> format_num(temp_f) <> " °F)", else: "")
    feels_part = "  (feels like " <> style(:bright, "#{format_num(feels)}°C") <> ")"

    [
      style(:bright, title) <> "    " <> style(:cyan, "Updated #{updated}"),
      "",
      "    " <> accent.(icon <> "  " <> desc),
      "",
      "    " <> temp_label <> f_part <> feels_part,
      "",
      "    " <>
        String.pad_trailing("Wind", 12) <>
        "#{beaufort_label(data.wind_speed_ms)}, #{format_num(data.wind_speed_ms)} m/s",
      "    " <> String.pad_trailing("Humidity", 12) <> "#{format_num(data.humidity_percent)}%",
      "    " <> String.pad_trailing("Pressure", 12) <> "#{format_num(data.pressure_hpa)} hPa",
      "    " <>
        String.pad_trailing("Dew point", 12) <>
        "#{format_num(estimate_dew_point(temp_c, data.humidity_percent))} °C",
      "",
      "    Comfort: " <> style(:yellow, comfort_score(data))
    ]
    |> Enum.join("\n")
  end

  @spec error(String.t()) :: String.t()
  def error(message) do
    [
      IO.ANSI.red(),
      IO.ANSI.bright(),
      "Error: ",
      IO.ANSI.reset(),
      IO.ANSI.red(),
      message,
      IO.ANSI.reset()
    ]
    |> IO.iodata_to_binary()
  end

  @spec location_source_menu() :: String.t()
  def location_source_menu do
    [
      style(:bright, "Select location source"),
      "  #{style(:cyan, "1")}) Auto-detect from IP",
      "  #{style(:cyan, "2")}) Enter city manually"
    ]
    |> Enum.join("\n")
  end

  @spec usage() :: String.t()
  def usage do
    [
      style(:bright, "Weather CLI"),
      "",
      "Usage:",
      "  weather_cli [--auto] [--city <name>]",
      "",
      "Options:",
      "  -a, --auto         Auto-detect city from IP via ip-api.com",
      "  -c, --city <name>  Fetch weather for a specific city",
      "  -h, --help         Show this help message",
      "",
      "Examples:",
      "  weather_cli --auto",
      "  weather_cli --city \"Berlin\"",
      "  weather_cli"
    ]
    |> Enum.join("\n")
  end

  @spec temp_color(number()) :: (String.t() -> String.t())
  defp temp_color(temp) when temp <= 10.0, do: &style(:blue, &1)
  defp temp_color(temp) when temp >= 28.0, do: &style(:red, &1)
  defp temp_color(_temp), do: &style(:green, &1)

  @spec format_num(number()) :: String.t()
  defp format_num(number) when is_integer(number), do: Integer.to_string(number)
  defp format_num(number) when is_float(number), do: :erlang.float_to_binary(number, decimals: 1)

  @spec capitalize(String.t()) :: String.t()
  defp capitalize(text) do
    text
    |> String.downcase()
    |> String.capitalize()
  end

  @spec weather_icon(String.t()) :: String.t()
  defp weather_icon(description) do
    normalized = String.downcase(description)

    cond do
      String.contains?(normalized, "thunder") -> "⛈"
      String.contains?(normalized, "rain") -> "🌧"
      String.contains?(normalized, "snow") -> "❄"
      String.contains?(normalized, "cloud") -> "☁"
      String.contains?(normalized, "mist") or String.contains?(normalized, "fog") -> "🌫"
      String.contains?(normalized, "clear") -> "☀"
      true -> "🌤"
    end
  end

  @spec celsius_to_f(number()) :: float()
  defp celsius_to_f(celsius), do: celsius * 9.0 / 5.0 + 32.0

  @spec estimate_dew_point(number(), number()) :: float()
  defp estimate_dew_point(temp_c, humidity_percent) do
    temp_c - (100.0 - humidity_percent) / 5.0
  end

  @spec comfort_score(map()) :: String.t()
  defp comfort_score(data) do
    cond do
      data.humidity_percent > 80 and data.temperature_c > 28 -> "Humid & hot"
      data.humidity_percent > 75 -> "Sticky"
      data.temperature_c < 5 -> "Cold"
      data.temperature_c in 18..26 and data.humidity_percent in 35..65 -> "Comfortable"
      true -> "Moderate"
    end
  end

  @spec beaufort_label(number()) :: String.t()
  defp beaufort_label(speed_ms) when speed_ms < 0.3, do: "Calm"
  defp beaufort_label(speed_ms) when speed_ms < 1.6, do: "Light air"
  defp beaufort_label(speed_ms) when speed_ms < 3.4, do: "Light breeze"
  defp beaufort_label(speed_ms) when speed_ms < 5.5, do: "Gentle breeze"
  defp beaufort_label(speed_ms) when speed_ms < 8.0, do: "Moderate breeze"
  defp beaufort_label(speed_ms) when speed_ms < 10.8, do: "Fresh breeze"
  defp beaufort_label(speed_ms) when speed_ms < 13.9, do: "Strong breeze"
  defp beaufort_label(_speed_ms), do: "High wind"

  @spec now_utc() :: String.t()
  defp now_utc do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  @spec style(atom(), String.t()) :: String.t()
  defp style(:bright, text), do: IO.ANSI.format([:bright, text]) |> IO.iodata_to_binary()
  defp style(:red, text), do: IO.ANSI.format([:red, text]) |> IO.iodata_to_binary()
  defp style(:green, text), do: IO.ANSI.format([:green, text]) |> IO.iodata_to_binary()
  defp style(:yellow, text), do: IO.ANSI.format([:yellow, text]) |> IO.iodata_to_binary()
  defp style(:blue, text), do: IO.ANSI.format([:blue, text]) |> IO.iodata_to_binary()
  defp style(:cyan, text), do: IO.ANSI.format([:cyan, text]) |> IO.iodata_to_binary()
end
