defmodule WeatherCli.Env do
  @moduledoc """
  Lightweight `.env` loader.

  Existing environment variables are preserved, so shell-provided values always win.
  """

  @valid_key ~r/^[A-Za-z_][A-Za-z0-9_]*$/

  @spec load(String.t()) :: :ok
  def load(path \\ ".env") do
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.each(&parse_and_put/1)

      {:error, _reason} ->
        :ok
    end

    :ok
  end

  @spec parse_and_put(String.t()) :: :ok
  defp parse_and_put(line) do
    trimmed =
      line
      |> String.trim()
      |> String.trim_leading("export ")

    cond do
      trimmed == "" ->
        :ok

      String.starts_with?(trimmed, "#") ->
        :ok

      true ->
        case String.split(trimmed, "=", parts: 2) do
          [key, value] ->
            final_key = String.trim(key)

            final_value =
              value
              |> String.trim()
              |> strip_quotes()
              |> String.trim()

            maybe_put(final_key, final_value)

          _ ->
            :ok
        end
    end
  end

  @spec strip_quotes(String.t()) :: String.t()
  defp strip_quotes(value) do
    value
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
  end

  @spec maybe_put(String.t(), String.t()) :: :ok
  defp maybe_put("", _value), do: :ok

  defp maybe_put(key, value) do
    cond do
      not Regex.match?(@valid_key, key) ->
        :ok

      System.get_env(key) == nil ->
        System.put_env(key, value)

      true ->
        :ok
    end
  end
end
