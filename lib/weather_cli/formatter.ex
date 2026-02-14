defmodule WeatherCli.Formatter do
  @moduledoc """
  Terminal renderer for weather output and errors.
  """

  @card_width 56

  @spec weather(map()) :: String.t()
  def weather(data) do
    title = "Current Weather · #{data.city}, #{data.country}"
    accent = temp_color(data.temperature_c)

    [
      top_border(accent),
      row(accent, style(:bright, title)),
      row(accent, ""),
      row(
        accent,
        line("Condition", "#{weather_icon(data.description)} #{capitalize(data.description)}")
      ),
      row(accent, line("Temperature", "#{format_num(data.temperature_c)} °C")),
      row(accent, line("Feels like", "#{format_num(data.feels_like_c)} °C")),
      row(accent, line("Humidity", "#{format_num(data.humidity_percent)} %")),
      row(accent, line("Pressure", "#{format_num(data.pressure_hpa)} hPa")),
      row(accent, line("Wind speed", "#{format_num(data.wind_speed_ms)} m/s")),
      bottom_border(accent)
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

  @spec row((String.t() -> String.t()), String.t()) :: String.t()
  defp row(accent, content) do
    [accent.("│ "), content]
    |> IO.iodata_to_binary()
  end

  @spec line(String.t(), String.t()) :: String.t()
  defp line(label, value) do
    [style(:yellow, String.pad_trailing(label <> ":", 12)), " ", style(:bright, value)]
    |> IO.iodata_to_binary()
  end

  @spec top_border((String.t() -> String.t())) :: String.t()
  defp top_border(accent), do: accent.("╭" <> String.duplicate("─", @card_width) <> "╮")

  @spec bottom_border((String.t() -> String.t())) :: String.t()
  defp bottom_border(accent), do: accent.("╰" <> String.duplicate("─", @card_width) <> "╯")

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

  @spec style(atom(), String.t()) :: String.t()
  defp style(:bright, text), do: IO.ANSI.format([:bright, text]) |> IO.iodata_to_binary()
  defp style(:red, text), do: IO.ANSI.format([:red, text]) |> IO.iodata_to_binary()
  defp style(:green, text), do: IO.ANSI.format([:green, text]) |> IO.iodata_to_binary()
  defp style(:yellow, text), do: IO.ANSI.format([:yellow, text]) |> IO.iodata_to_binary()
  defp style(:blue, text), do: IO.ANSI.format([:blue, text]) |> IO.iodata_to_binary()
  defp style(:cyan, text), do: IO.ANSI.format([:cyan, text]) |> IO.iodata_to_binary()
end
