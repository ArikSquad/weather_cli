defmodule WeatherCli do
  @moduledoc """
  Weather CLI for Linux/macOS terminals.
  """

  @ip_api_url "http://ip-api.com/json/"
  @weather_url "https://api.openweathermap.org/data/2.5/weather"
  @http_opts [timeout: 5_000]
  @missing_api_key_msg "Missing OPENWEATHER_API_KEY. Add it to your shell env or to a .env file in project root."

  @typedoc "Runtime dependency injection for testability."
  @type deps :: %{
          puts: (String.t() -> any()),
          gets: (String.t() -> String.t() | nil),
          http_get: (String.t(), map(), keyword() -> {:ok, map()} | {:error, String.t()}),
          http_opts: keyword(),
          env_loader: (String.t() -> :ok),
          env_file: String.t(),
          ip_api_url: String.t(),
          weather_url: String.t()
        }

  @doc """
  CLI entrypoint used by `mix escript.build` binaries.
  """
  @spec main([String.t()]) :: :ok
  def main(argv) do
    _ = run(argv)
    :ok
  end

  @doc """
  Executes the weather flow.

  Returns `{:ok, weather_map}` on success or `{:error, reason}` on failure.
  """
  @spec run([String.t()], deps()) :: {:ok, map()} | {:error, String.t()}
  def run(argv, deps \\ default_deps()) do
    deps.env_loader.(deps.env_file)

    with {:ok, options} <- parse_args(argv),
         {:ok, api_key} <- fetch_api_key(),
         {:ok, city} <- resolve_city(options, deps),
         {:ok, weather_data} <- fetch_weather(city, api_key, deps) do
      deps.puts.(WeatherCli.Formatter.weather(weather_data))
      {:ok, weather_data}
    else
      {:help, help_text} ->
        deps.puts.(help_text)
        {:ok, %{}}

      {:error, reason} = error ->
        deps.puts.(WeatherCli.Formatter.error(reason))
        error
    end
  end

  @spec default_deps() :: deps()
  def default_deps do
    %{
      puts: &IO.puts/1,
      gets: &IO.gets/1,
      http_get: &WeatherCli.HTTP.get/3,
      http_opts: @http_opts,
      env_loader: &WeatherCli.Env.load/1,
      env_file: ".env",
      ip_api_url: @ip_api_url,
      weather_url: @weather_url
    }
  end

  @spec parse_args([String.t()]) :: {:ok, map()} | {:help, String.t()} | {:error, String.t()}
  defp parse_args(argv) do
    {opts, _args, invalid} =
      OptionParser.parse(argv,
        strict: [city: :string, auto: :boolean, help: :boolean],
        aliases: [c: :city, a: :auto, h: :help]
      )

    cond do
      opts[:help] ->
        {:help, WeatherCli.Formatter.usage()}

      invalid != [] ->
        {:error, "Invalid options: #{inspect(invalid)}\n\n#{WeatherCli.Formatter.usage()}"}

      true ->
        {:ok, %{city: opts[:city], auto: opts[:auto] == true}}
    end
  end

  @spec fetch_api_key() :: {:ok, String.t()} | {:error, String.t()}
  defp fetch_api_key do
    case System.get_env("OPENWEATHER_API_KEY") do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if byte_size(trimmed) > 0 do
          {:ok, trimmed}
        else
          {:error, @missing_api_key_msg}
        end

      _ ->
        {:error, @missing_api_key_msg}
    end
  end

  @spec resolve_city(map(), deps()) :: {:ok, String.t()} | {:error, String.t()}
  defp resolve_city(%{city: city}, _deps) when is_binary(city) do
    trimmed = String.trim(city)

    if byte_size(trimmed) > 0 do
      {:ok, trimmed}
    else
      {:error, "City cannot be empty."}
    end
  end

  defp resolve_city(%{auto: true}, deps), do: detect_city_from_ip(deps)

  defp resolve_city(_options, deps) do
    deps.puts.(WeatherCli.Formatter.location_source_menu())

    case safe_gets("> ", deps) do
      "1" -> detect_city_from_ip(deps)
      "2" -> ask_for_city(deps)
      _ -> {:error, "Please choose 1 or 2."}
    end
  end

  @spec ask_for_city(deps()) :: {:ok, String.t()} | {:error, String.t()}
  defp ask_for_city(deps) do
    case safe_gets("City: ", deps) do
      city when byte_size(city) > 0 -> {:ok, city}
      _ -> {:error, "City cannot be empty."}
    end
  end

  @spec detect_city_from_ip(deps()) :: {:ok, String.t()} | {:error, String.t()}
  defp detect_city_from_ip(deps) do
    with {:ok, payload} <- deps.http_get.(deps.ip_api_url, %{}, deps.http_opts),
         :ok <- ensure_ip_success(payload),
         {:ok, city} <- map_string(payload, "city") do
      {:ok, city}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ensure_ip_success(map()) :: :ok | {:error, String.t()}
  defp ensure_ip_success(%{"status" => "success"}), do: :ok

  defp ensure_ip_success(payload) do
    message = Map.get(payload, "message", "Unknown IP API error")

    {:error, "IP lookup failed: #{message}"}
  end

  @spec fetch_weather(String.t(), String.t(), deps()) :: {:ok, map()} | {:error, String.t()}
  defp fetch_weather(city, api_key, deps) do
    params = %{"q" => city, "appid" => api_key, "units" => "metric"}

    with {:ok, payload} <- deps.http_get.(deps.weather_url, params, deps.http_opts),
         :ok <- ensure_weather_success(payload),
         {:ok, normalized} <- normalize_weather(payload) do
      {:ok, normalized}
    end
  end

  @spec ensure_weather_success(map()) :: :ok | {:error, String.t()}
  defp ensure_weather_success(payload) do
    cond do
      is_map(payload["main"]) and is_map(payload["wind"]) and is_list(payload["weather"]) ->
        :ok

      true ->
        message = Map.get(payload, "message", "Unknown OpenWeatherMap error")
        {:error, "OpenWeatherMap error: #{message}"}
    end
  end

  @spec normalize_weather(map()) :: {:ok, map()} | {:error, String.t()}
  defp normalize_weather(payload) do
    with {:ok, city} <- map_string(payload, "name"),
         {:ok, sys} <- map_submap(payload, "sys"),
         {:ok, country} <- map_string(sys, "country"),
         {:ok, weather_items} <- map_list(payload, "weather"),
         {:ok, weather_head} <- first_map(weather_items),
         {:ok, description} <- map_string(weather_head, "description"),
         {:ok, main} <- map_submap(payload, "main"),
         {:ok, temp} <- map_number(main, "temp"),
         {:ok, feels_like} <- map_number(main, "feels_like"),
         {:ok, humidity} <- map_number(main, "humidity"),
         {:ok, pressure} <- map_number(main, "pressure"),
         {:ok, wind} <- map_submap(payload, "wind"),
         {:ok, wind_speed} <- map_number(wind, "speed") do
      {:ok,
       %{
         city: city,
         country: country,
         description: description,
         temperature_c: temp,
         feels_like_c: feels_like,
         humidity_percent: humidity,
         pressure_hpa: pressure,
         wind_speed_ms: wind_speed
       }}
    else
      _ -> {:error, "Weather payload is missing required fields."}
    end
  end

  @spec map_string(map(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp map_string(map, key) do
    case map[key] do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if byte_size(trimmed) > 0 do
          {:ok, trimmed}
        else
          {:error, "Missing string field: #{key}"}
        end

      _ ->
        {:error, "Missing string field: #{key}"}
    end
  end

  @spec map_submap(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defp map_submap(map, key) do
    case map[key] do
      value when is_map(value) -> {:ok, value}
      _ -> {:error, "Missing object field: #{key}"}
    end
  end

  @spec map_list(map(), String.t()) :: {:ok, list()} | {:error, String.t()}
  defp map_list(map, key) do
    case map[key] do
      value when is_list(value) -> {:ok, value}
      _ -> {:error, "Missing list field: #{key}"}
    end
  end

  @spec first_map(list()) :: {:ok, map()} | {:error, String.t()}
  defp first_map([head | _]) when is_map(head), do: {:ok, head}
  defp first_map(_), do: {:error, "Missing first weather item"}

  @spec map_number(map(), String.t()) :: {:ok, float()} | {:error, String.t()}
  defp map_number(map, key) do
    case map[key] do
      value when is_integer(value) ->
        {:ok, value * 1.0}

      value when is_float(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Float.parse(value) do
          {number, ""} -> {:ok, number}
          _ -> {:error, "Invalid numeric field: #{key}"}
        end

      _ ->
        {:error, "Missing numeric field: #{key}"}
    end
  end

  @spec safe_gets(String.t(), deps()) :: String.t()
  defp safe_gets(prompt, deps) do
    deps.gets.(prompt)
    |> Kernel.||("")
    |> String.trim()
  end
end
