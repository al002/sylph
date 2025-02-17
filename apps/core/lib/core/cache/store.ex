defmodule Core.Cache.Store do
  require Logger
  require Cachex.Spec
  alias Core.Telemetry.Events

  @type cache_name :: :block_cache | :transaction_cache | :token_cache
  @type cache_key :: String.t() | integer()
  @type cache_value :: term()
  @type ttl :: non_neg_integer() | :infinity
  @type cache_result :: {:commit, cache_value} | {:error, term()}

  @default_ttl :timer.minutes(30)
  @default_max_size 100_000

  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    max_size = Keyword.get(opts, :max_size, @default_max_size)

    cache_opts = [
      hooks: [
        Cachex.Spec.hook(module: Cachex.Stats),
        Cachex.Spec.hook(
          module: Cachex.Limit.Scheduled,
          args: {
            max_size,
            [reclaim: 0.1],
            [interval: :timer.seconds(30)]
          }
        )
      ],
      expiration:
        Cachex.Spec.expiration(
          interval: :timer.seconds(5),
          lazy: true
        )
    ]

    Supervisor.child_spec(
      {Cachex, Keyword.merge(cache_opts, name: name)},
      id: name
    )
  end

  @spec get(cache_name(), cache_key()) :: cache_result()
  def get(cache, key) do
    start_time = System.monotonic_time()

    result = Cachex.fetch(cache, key, &cache_fetch_fallback/1)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:cache, :get],
      %{duration: duration},
      %{cache: cache, key: key, hit: match?({:ok, _}, result)}
    )

    result
  end

  @spec put(cache_name(), cache_key(), cache_value(), ttl()) :: cache_result()
  def put(cache, key, value, ttl \\ @default_ttl) do
    start_time = System.monotonic_time()

    result = Cachex.put(cache, key, value, ttl: ttl)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:cache, :put],
      %{duration: duration},
      %{cache: cache, key: key}
    )

    result
  end

  @spec get_or_store(cache_name(), cache_key(), (-> cache_value()), ttl()) :: cache_result()
  def get_or_store(cache, key, func, ttl \\ @default_ttl) do
    start_time = System.monotonic_time()

    result =
      Cachex.get_and_update(cache, key, fn
        {:ok, value} ->
          {:commit, value}

        :not_found ->
          case safe_execute(func) do
            {:commit, value} -> {:commit, value, ttl: ttl}
            error -> error
          end
      end)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:cache, :get_or_store],
      %{duration: duration},
      %{
        cache: cache,
        key: key,
        computed: !match?({:ok, _}, Cachex.fetch(cache, key, &cache_fetch_fallback/1))
      }
    )

    result
  end

  @spec delete(cache_name(), cache_key()) :: cache_result()
  def delete(cache, key) do
    start_time = System.monotonic_time()

    result = Cachex.del(cache, key)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:cache, :delete],
      %{duration: duration},
      %{cache: cache, key: key}
    )

    result
  end

  @spec clear(cache_name()) :: cache_result()
  def clear(cache) do
    start_time = System.monotonic_time()

    result = Cachex.clear(cache)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      Events.prefix() ++ [:cache, :clear],
      %{duration: duration},
      %{cache: cache}
    )

    result
  end

  @spec stats(cache_name()) :: map()
  def stats(cache) do
    {:ok, stats} = Cachex.stats(cache)
    stats
  end

  defp safe_execute(func) do
    try do
      case func.() do
        {:ok, value} -> {:commit, value}
        {:ok, value, opts} when is_list(opts) -> {:commit, value, opts}
        value -> {:commit, value}
      end
    rescue
      e ->
        Logger.error("Cache computation error: #{Exception.message(e)}")

        :telemetry.execute(
          Events.prefix() ++ [:cache, :computation_error],
          %{timestamp: System.system_time()},
          %{error: Exception.message(e)}
        )

        {:ignore, nil}
    end
  end

  defp cache_fetch_fallback(key) do
    Logger.debug("Cache miss for key: #{inspect(key)}")
    {:ok, nil}
  end
end

# defmodule Core.Cache.Store do
#   use GenServer
#   require Logger
#   require Cachex.Spec
#   alias Core.Telemetry.Events
#
#   @type cache_name :: :block_cache | :transaction_cache | :token_cache
#   @type cache_key :: String.t() | integer()
#   @type cache_value :: term()
#   @type ttl :: non_neg_integer() | :infinity
#   @type cache_result :: {:commit, cache_value} | {:error, term()}
#
#   @default_ttl :timer.minutes(30)
#   @default_max_size 100_000
#
#   def start_link(opts) do
#     name = Keyword.fetch!(opts, :name)
#     GenServer.start_link(__MODULE__, opts, name: name)
#   end
#
#   @spec get(cache_name(), cache_key()) :: cache_result()
#   def get(cache, key) do
#     start_time = System.monotonic_time()
#
#     result = Cachex.fetch(cache, key, &cache_fetch_fallback/1)
#
#     duration = System.monotonic_time() - start_time
#
#     :telemetry.execute(
#       Events.prefix() ++ [:cache, :get],
#       %{duration: duration},
#       %{cache: cache, key: key, hit: match?({:ok, _}, result)}
#     )
#
#     result
#   end
#
#   @spec put(cache_name(), cache_key(), cache_value(), ttl()) :: cache_result()
#   def put(cache, key, value, ttl \\ @default_ttl) do
#     start_time = System.monotonic_time()
#
#     result = Cachex.put(cache, key, value, ttl: ttl)
#
#     duration = System.monotonic_time() - start_time
#
#     :telemetry.execute(
#       Events.prefix() ++ [:cache, :put],
#       %{duration: duration},
#       %{cache: cache, key: key}
#     )
#
#     result
#   end
#
#   @spec get_or_store(cache_name(), cache_key(), (-> cache_value()), ttl()) :: cache_result()
#   def get_or_store(cache, key, func, ttl \\ @default_ttl) do
#     start_time = System.monotonic_time()
#
#     result =
#       Cachex.get_and_update(cache, key, fn
#         {:ok, value} ->
#           {:commit, value}
#
#         :not_found ->
#           case safe_execute(func) do
#             {:commit, value} -> {:commit, value, ttl: ttl}
#             error -> error
#           end
#       end)
#
#     duration = System.monotonic_time() - start_time
#
#     :telemetry.execute(
#       Events.prefix() ++ [:cache, :get_or_store],
#       %{duration: duration},
#       %{
#         cache: cache,
#         key: key,
#         computed: !match?({:ok, _}, Cachex.fetch(cache, key, &cache_fetch_fallback/1))
#       }
#     )
#
#     result
#   end
#
#   @spec delete(cache_name(), cache_key()) :: cache_result()
#   def delete(cache, key) do
#     start_time = System.monotonic_time()
#
#     result = Cachex.del(cache, key)
#
#     duration = System.monotonic_time() - start_time
#
#     :telemetry.execute(
#       Events.prefix() ++ [:cache, :delete],
#       %{duration: duration},
#       %{cache: cache, key: key}
#     )
#
#     result
#   end
#
#   @spec clear(cache_name()) :: cache_result()
#   def clear(cache) do
#     start_time = System.monotonic_time()
#
#     result = Cachex.clear(cache)
#
#     duration = System.monotonic_time() - start_time
#
#     :telemetry.execute(
#       Events.prefix() ++ [:cache, :clear],
#       %{duration: duration},
#       %{cache: cache}
#     )
#
#     result
#   end
#
#   @spec stats(cache_name()) :: map()
#   def stats(cache) do
#     {:ok, stats} = Cachex.stats(cache)
#     stats
#   end
#
#   # Server Callbacks
#
#   @impl true
#   def init(opts) do
#     cache_name = Keyword.fetch!(opts, :name)
#
#     Logger.info("Starting cache store: #{cache_name}")
#
#     ttl = Keyword.get(opts, :ttl, @default_ttl)
#     max_size = Keyword.get(opts, :max_size, @default_max_size)
#
#     cache_opts = [
#       hooks: [
#         Cachex.Spec.hook(module: Cachex.Stats),
#         Cachex.Spec.hook(
#           module: Cachex.Limit.Scheduled,
#           args: {
#             max_size,
#             [reclaim: 0.1],
#             [interval: :timer.seconds(30)]
#           }
#         )
#       ],
#       expiration: [
#         interval: :timer.seconds(5),
#         lazy: true
#       ]
#     ]
#
#     case Cachex.start_link(cache_opts ++ [name: cache_name]) do
#       {:ok, _pid} ->
#         :telemetry.execute(
#           Events.prefix() ++ [:cache, :start],
#           %{timestamp: System.system_time()},
#           %{name: cache_name}
#         )
#
#         {:ok, %{name: cache_name, ttl: ttl}}
#
#       {:error, reason} = error ->
#         Logger.error("Failed to start cache #{cache_name}: #{inspect(reason)}")
#         error
#     end
#   end
#
#   defp safe_execute(func) do
#     try do
#       case func.() do
#         {:ok, value} -> {:commit, value}
#         {:ok, value, opts} when is_list(opts) -> {:commit, value, opts}
#         value -> {:commit, value}
#       end
#     rescue
#       e ->
#         Logger.error("Cache computation error: #{Exception.message(e)}")
#
#         :telemetry.execute(
#           Events.prefix() ++ [:cache, :computation_error],
#           %{timestamp: System.system_time()},
#           %{error: Exception.message(e)}
#         )
#
#         {:ignore, nil}
#     end
#   end
#
#   defp cache_fetch_fallback(key) do
#     Logger.debug("Cache miss for key: #{inspect(key)}")
#     {:ok, nil}
#   end
# end
