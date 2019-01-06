defmodule RedixCluster do
  @moduledoc """
  This module provides the main API to interface with Redis Cluster by Redix.

  `Make sure` CROSSSLOT Keys in request hash to the same slot
  """
  use Supervisor

  @type command :: [binary]

  @max_retry 20
  @redis_retry_delay 100

  @doc """
    Starts RedixCluster.
  """
  @spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    {cache_name, _opts} = Keyword.pop(opts, :cache_name, ShieldedCache)
    name = Module.concat(cache_name, CachingModule)
    Supervisor.start_link(__MODULE__, cache_name, name: name)
  end

  @spec init(cache_name :: module) :: Supervisor.on_start()
  def init(cache_name) do
    children = [
      %{
        id: Module.concat(cache_name, Pool),
        start: {RedixCluster.Pool, :start_link, [[cache_name: cache_name]]},
        type: :supervisor
      },
      %{
        id: Module.concat(cache_name, Monitor),
        start: {RedixCluster.Monitor, :start_link, [[cache_name: cache_name]]},
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  This function works exactly like `Redix.command/3`
  ## Examples

      iex> RedixCluster.command(~w(SET mykey foo))
      {:ok, "OK"}

      iex> RedixCluster.command(~w(GET mykey))
      {:ok, "foo"}

      iex> RedixCluster.command(~w(INCR mykey zhongwen))
      {:error,
       %Redix.Error{message: "ERR wrong number of arguments for 'incr' command"}}

      iex> RedixCluster.command(~w(mget ym d ))
      {:error,
       %Redix.Error{message: "CROSSSLOT Keys in request don't hash to the same slot"}}

      iex> RedixCluster.command(~w(mset {keysamehash}ym 1 {keysamehash}d 2 ))
      {:ok, "OK"}

      iex> RedixCluster.command(~w(mget {keysamehash}ym {keysamehash}d ))
      {:ok, ["1", "2"]}

  """
  @spec command(String.t(), String.t(), Keyword.t()) ::
          {:ok, Redix.Protocol.redis_value()}
          | {:error, Redix.Error.t() | atom}
  def command(cache_name, command, opts \\ []), do: command(cache_name, command, opts, 0)

  @doc """
  This function works exactly like `Redix.pipeline/3`

  ## Examples

      iex> RedixCluster.pipeline([~w(INCR mykey), ~w(INCR mykey), ~w(DECR mykey)])
      {:ok, [1, 2, 1]}

      iex> RedixCluster.pipeline([~w(SET {samehash}k3 foo), ~w(INCR {samehash}k2), ~w(GET {samehash}k1)])
      {:ok, ["OK", 1, nil]}

      iex> RedixCluster.pipeline([~w(SET {diffhash3}k3 foo), ~w(INCR {diffhash2}k2), ~w(GET {diffhash1}k1)])
      {:error, :key_must_same_slot}

  """
  @spec pipeline(String.t(), [command], Keyword.t()) ::
          {:ok, [Redix.Protocol.redis_value()]}
          | {:error, atom}
  def pipeline(cache_name, commands, opts \\ []), do: pipeline(cache_name, commands, opts, 0)

  defp command(_cache_name, _command, _opts, count) when count >= @max_retry,
    do: {:error, :no_connection}

  defp command(cache_name, command, opts, count) do
    unless count == 0, do: :timer.sleep(@redis_retry_delay)

    RedixCluster.Run.command(cache_name, command, opts)
    |> need_retry(command, opts, count, :command)
  end

  defp pipeline(_cache_name, _commands, _opts, count) when count >= @max_retry,
    do: {:error, :no_connection}

  defp pipeline(cache_name, commands, opts, count) do
    unless count == 0, do: :timer.sleep(@redis_retry_delay)

    RedixCluster.Run.pipeline(cache_name, commands, opts)
    |> need_retry(commands, opts, count, :pipeline)
  end

  defp need_retry({:error, :retry}, command, opts, count, :command),
    do: command(command, opts, count + 1)

  defp need_retry({:error, :retry}, commands, opts, count, :pipeline),
    do: pipeline(commands, opts, count + 1)

  defp need_retry(result, _command, _count, _opts, _type), do: result
end
