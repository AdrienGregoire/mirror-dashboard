#
## EPITECH PROJECT, 2026
## load_test.exs
## File description:
## A load test on /login endpoint
#

target_url = "http://localhost:4000/login"
total_requests = 50_000
concurrency = 1000

test_email = "adrien.gregoire@epitech.eu"
test_password = "azerty123"

IO.puts("Starting load test on #{target_url}...")
IO.puts("Total requests: #{total_requests} | Concurrency : #{concurrency}\n")

parse_cookie = fn
  values when is_list(values) ->
    values
    |> Enum.map(fn v -> String.split(v, ";") |> List.first() end)
    |> Enum.join("; ")

  value when is_binary(value) ->
    String.split(value, ";") |> List.first()
end

init_session = fn ->
  case Req.get(target_url) do
    {:ok, %{status: 200, body: body, headers: headers}} ->
      csrf_token =
        cond do
          match = Regex.run(~r/name="_csrf_token"\s+value="([^"]+)"/, body) -> Enum.at(match, 1)
          match = Regex.run(~r/value="([^"]+)"\s+name="_csrf_token"/, body) -> Enum.at(match, 1)
          match = Regex.run(~r/name="csrf-token"\s+content="([^"]+)"/, body) -> Enum.at(match, 1)
          true -> nil
        end

      cookies =
        headers
        |> Enum.filter(fn {k, _} -> String.downcase(k) == "set-cookie" end)
        |> Enum.map(fn {_, v} -> parse_cookie.(v) end)
        |> Enum.join("; ")

      if csrf_token && cookies != "" do
        {:ok, csrf_token, cookies}
      else
        {:error, "CSRF token or cookie not found in the response."}
      end

    _ ->
      {:error, "Unable to load the login page."}
  end
end

case init_session.() do
  {:ok, csrf_token, cookies} ->
    IO.puts("CSRF token retrieved: #{String.slice(csrf_token, 0..15)}...")
    IO.puts("Session cookie retrieved: #{String.slice(cookies, 0..25)}...\n")

    start_time = System.monotonic_time(:millisecond)

    results =
      1..total_requests
      |> Task.async_stream(
        fn _i ->
          req_start = System.monotonic_time(:millisecond)

          form_data = [
            {"_csrf_token", csrf_token},
            {"user[email]", test_email},
            {"user[password]", test_password}
          ]

          case Req.post(target_url,
                 form: form_data,
                 headers: [{"cookie", cookies}],
                 redirect: false
               ) do
            {:ok, %{status: status}} when status in [200, 302] ->
              duration = System.monotonic_time(:millisecond) - req_start
              {:ok, duration}

            {:ok, %{status: status}} ->
              {:error, "HTTP #{status}"}

            {:error, reason} ->
              {:error, reason}
          end
        end,
        max_concurrency: concurrency,
        timeout: 15_000
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, reason}
      end)

    total_duration = (System.monotonic_time(:millisecond) - start_time) / 1000

    successes = Enum.filter(results, &match?({:ok, _}, &1))
    failures = Enum.filter(results, &match?({:error, _}, &1))

    durations = Enum.map(successes, fn {:ok, d} -> d end)

    avg_duration =
      if Enum.any?(durations),
        do: Enum.sum(durations) / length(durations),
        else: 0.0

    IO.puts("Results")
    IO.puts("Execution time: #{Float.round(total_duration, 2)}s")
    IO.puts("Success: #{length(successes)} / #{total_requests}")
    IO.puts("Failures: #{length(failures)} / #{total_requests}")
    IO.puts("Speed: #{Float.round(length(successes) / total_duration, 2)} req/s")
    IO.puts("Average response time: #{Float.round(avg_duration * 1.0, 2)} ms")
end
