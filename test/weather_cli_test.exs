defmodule WeatherCliTest do
  use ExUnit.Case

  setup do
    original = System.get_env("OPENWEATHER_API_KEY")

    on_exit(fn ->
      if original do
        System.put_env("OPENWEATHER_API_KEY", original)
      else
        System.delete_env("OPENWEATHER_API_KEY")
      end
    end)

    :ok
  end

  test "returns weather for --city option" do
    System.put_env("OPENWEATHER_API_KEY", "test-key")
    test_pid = self()

    deps =
      deps_for_test(test_pid,
        inputs: [],
        http: fn _url, params, _opts ->
          assert params["q"] == "Berlin"
          {:ok, weather_payload("Berlin", "DE")}
        end
      )

    assert {:ok, result} = WeatherCli.run(["--city", "Berlin"], deps)
    assert result.city == "Berlin"
    assert_received {:puts, output}
    assert output =~ "Berlin"
  end

  test "auto mode fetches city from IP API then weather" do
    System.put_env("OPENWEATHER_API_KEY", "test-key")
    test_pid = self()

    deps =
      deps_for_test(test_pid,
        inputs: [],
        http: fn url, _params, _opts ->
          cond do
            String.contains?(url, "ip-api.com") ->
              {:ok, ip_success_payload("Porto")}

            String.contains?(url, "openweathermap") ->
              {:ok, weather_payload("Porto", "PT")}

            true ->
              {:error, "unexpected URL"}
          end
        end
      )

    assert {:ok, result} = WeatherCli.run(["--auto"], deps)
    assert result.city == "Porto"
  end

  test "interactive mode accepts manual city input" do
    System.put_env("OPENWEATHER_API_KEY", "test-key")
    test_pid = self()

    deps =
      deps_for_test(test_pid,
        inputs: ["2\n", "Lisbon\n"],
        http: fn _url, params, _opts ->
          assert params["q"] == "Lisbon"
          {:ok, weather_payload("Lisbon", "PT")}
        end
      )

    assert {:ok, result} = WeatherCli.run([], deps)
    assert result.city == "Lisbon"
    assert_received {:puts, menu_text}
    assert menu_text =~ "Select location source"
  end

  test "prints help" do
    System.put_env("OPENWEATHER_API_KEY", "test-key")
    test_pid = self()

    deps =
      deps_for_test(test_pid, inputs: [], http: fn _url, _params, _opts -> {:error, "unused"} end)

    assert {:ok, %{}} = WeatherCli.run(["--help"], deps)
    assert_received {:puts, help}
    assert help =~ "Usage"
  end

  test "returns error when API key is missing" do
    System.delete_env("OPENWEATHER_API_KEY")
    test_pid = self()

    deps =
      deps_for_test(test_pid, inputs: [], http: fn _url, _params, _opts -> {:error, "unused"} end)

    assert {:error, message} = WeatherCli.run(["--city", "Madrid"], deps)
    assert message =~ "OPENWEATHER_API_KEY"
    assert_received {:puts, output}
    assert output =~ "Error:"
  end

  defp deps_for_test(test_pid, opts) do
    {:ok, input_agent} = Agent.start_link(fn -> opts[:inputs] || [] end)

    %{
      puts: fn text -> send(test_pid, {:puts, text}) end,
      gets: fn _prompt -> Agent.get_and_update(input_agent, &next_input/1) end,
      http_get: opts[:http],
      http_opts: [timeout: 1_000],
      env_loader: fn _ -> :ok end,
      env_file: ".env.test",
      ip_api_url: "http://ip-api.com/json/",
      weather_url: "https://api.openweathermap.org/data/2.5/weather"
    }
  end

  defp next_input([head | tail]), do: {head, tail}
  defp next_input([]), do: {nil, []}

  defp ip_success_payload(city) do
    %{
      "status" => "success",
      "city" => city
    }
  end

  defp weather_payload(city, country) do
    %{
      "name" => city,
      "sys" => %{"country" => country},
      "main" => %{
        "temp" => 18.5,
        "feels_like" => 17.2,
        "humidity" => 65,
        "pressure" => 1012
      },
      "wind" => %{"speed" => 4.8},
      "weather" => [%{"description" => "clear sky"}]
    }
  end
end
