defmodule RedixCluster do
  @moduledoc """
  This module provides the main API to interface with Redis Cluster by Redix.

  `Make sure` CROSSSLOT Keys in request hash to the same slot
  """
  @type command :: [binary]

  @max_retry 20
  @redis_retry_delay 100

  @doc """
    Starts RedixCluster.
  """
  @spec start(Keyword.t()) :: Supervisor.on_start()
  def start(opts \\ []), do: RedixCluster.Supervisor.start_link(opts)

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
  @spec command(String.t(), Keyword.t()) ::
          {:ok, Redix.Protocol.redis_value()}
          | {:error, Redix.Error.t() | atom}
  def command(command, opts \\ []), do: command(command, opts, 0)

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
  @spec pipeline([command], Keyword.t()) ::
          {:ok, [Redix.Protocol.redis_value()]}
          | {:error, atom}
  def pipeline(commands, opts \\ []), do: pipeline(commands, opts, 0)

  defp command(_command, _opts, count) when count >= @max_retry, do: {:error, :no_connection}

  defp command(command, opts, count) do
    unless count == 0, do: :timer.sleep(@redis_retry_delay)

    RedixCluster.Run.command(command, opts)
    |> need_retry(command, opts, count, :command)
  end

  defp pipeline(_commands, _opts, count) when count >= @max_retry, do: {:error, :no_connection}

  defp pipeline(commands, opts, count) do
    unless count == 0, do: :timer.sleep(@redis_retry_delay)

    RedixCluster.Run.pipeline(commands, opts)
    |> need_retry(commands, opts, count, :pipeline)
  end

  defp need_retry({:error, :retry}, command, opts, count, :command),
    do: command(command, opts, count + 1)

  defp need_retry({:error, :retry}, commands, opts, count, :pipeline),
    do: pipeline(commands, opts, count + 1)

  defp need_retry(result, _command, _count, _opts, _type), do: result
end
