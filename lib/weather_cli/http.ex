defmodule WeatherCli.HTTP do
  @moduledoc """
  Thin HTTP client wrapper powered by Erlang's built-in `:httpc`.
  """

  @type params :: map()
  @type error :: {:error, String.t()}

  @spec get(String.t(), params(), keyword()) :: {:ok, map()} | error()
  def get(url, params, opts \\ []) do
    with {:ok, body} <- run_request(build_url(url, params), opts) do
      decode_json(body)
    end
  end

  @spec run_request(String.t(), keyword()) :: {:ok, String.t()} | error()
  defp run_request(request_url, opts) do
    timeout_ms = Keyword.get(opts, :timeout, 5_000)

    request = {String.to_charlist(request_url), []}
    http_options = [timeout: timeout_ms, connect_timeout: timeout_ms, autoredirect: true]

    case :httpc.request(:get, request, http_options, body_format: :binary) do
      {:ok, {{_http_version, status_code, _reason_phrase}, _headers, body}}
      when status_code in 200..299 ->
        {:ok, body}

      {:ok, {{_http_version, status_code, _reason_phrase}, _headers, body}} ->
        {:error, "HTTP request failed (#{status_code}): #{compact_error_body(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @spec compact_error_body(binary()) :: String.t()
  defp compact_error_body(body) do
    body
    |> String.trim()
    |> case do
      "" -> "empty response body"
      text -> String.slice(text, 0, 240)
    end
  end

  @spec decode_json(String.t()) :: {:ok, map()} | error()
  defp decode_json(body) do
    case JSON.decode(body) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _other} -> {:error, "Unexpected JSON payload format."}
      {:error, reason} -> {:error, "Invalid JSON response: #{inspect(reason)}"}
    end
  end

  @spec build_url(String.t(), params()) :: String.t()
  defp build_url(url, params) when map_size(params) == 0, do: url

  defp build_url(url, params) do
    query = URI.encode_query(params)

    if String.contains?(url, "?") do
      "#{url}&#{query}"
    else
      "#{url}?#{query}"
    end
  end
end
