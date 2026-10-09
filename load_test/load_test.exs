#
## EPITECH PROJECT, 2026
## load_test.exs
## File description:
## A load test on /about.json endpoint
#

target_url = "http://localhost:4000/about.json"
total_requests = 50_000
concurrency = 1000

IO.puts("Starting load test on #{target_url}...")
IO.puts("Total request : #{total_requests} | Concurrency: #{concurrency}\n")

start_time = System.monotonic_time(:millisecond)

results =
  1..total_requests
  |> Task.async_stream(
    fn _i ->
      req_start = System.monotonic_time(:millisecond)

      case Req.get(target_url) do
        {:ok, %{status: 200}} ->
          duration = System.monotonic_time(:millisecond) - req_start
          {:ok, duration}

        {:ok, %{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          {:error, reason}
      end
    end,
    max_concurrency: concurrency,
    timeout: 10_000
  )
  |> Enum.map(fn
    {:ok, result} -> result
    {:exit, reason} -> {:error, reason}
  end)

total_duration = (System.monotonic_time(:millisecond) - start_time) / 1000
successes = Enum.filter(results, &match?({:ok, _}, &1))
failures = Enum.filter(results, &match?({:error, _}, &1))
durations = Enum.map(successes, fn {:ok, d} -> d end)
avg_duration = if Enum.any?(durations), do: Enum.sum(durations) / length(durations), else: 0

IO.puts("Results")
IO.puts("Execution Time: #{Float.round(total_duration, 2)}s")
IO.puts("Success: #{length(successes)} / #{total_requests}")
IO.puts("Failures: #{length(failures)} / #{total_requests}")
IO.puts("Speed: #{Float.round(length(successes) / total_duration, 2)} req/s")
IO.puts("Average response time: #{Float.round(avg_duration, 2)} ms")
