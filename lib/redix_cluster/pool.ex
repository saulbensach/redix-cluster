defmodule RedixCluster.Pool do
  @moduledoc false

  use Supervisor
  use RedixCluster.Helper

  @default_pool_size 10
  @default_pool_max_overflow 0
  @max_retry 20

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    {cache_name, _opts} = Keyword.pop(opts, :cache_name, ShieldedCache)
    table_name = Module.concat(cache_name, CachingModule.Pool)
    :ets.new(table_name, [:set, :named_table, :public])
    Supervisor.start_link(__MODULE__, nil, name: table_name)
  end

  def init(nil) do
    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec new_pool(String.t(), charlist, integer) :: {:ok, atom} | {:error, atom}
  def new_pool(cache_name, host, port) do
    pool_name = [cache_name, "-Pool-", host, ":", port] |> Enum.join() |> String.to_atom()
    table_name = Module.concat(cache_name, CachingModule.Pool)

    case Process.whereis(pool_name) do
      nil ->
        :ets.insert(table_name, {pool_name, 0})
        pool_size = get_env(:pool_size, @default_pool_size)
        pool_max_overflow = get_env(:pool_max_overflow, @default_pool_max_overflow)

        pool_args = [
          name: {:local, pool_name},
          worker_module: RedixCluster.Worker,
          size: pool_size,
          max_overflow: pool_max_overflow
        ]

        worker_args = [host: host, port: port, pool_name: pool_name]
        child_spec = :poolboy.child_spec(pool_name, pool_args, worker_args)
        {result, _} = Supervisor.start_child(table_name, child_spec)
        {result, pool_name}

      _ ->
        {:ok, pool_name}
    end
  end

  @spec register_worker_connection(String.t()) :: :ok
  def register_worker_connection(pool_name) do
    cache_name = pool_name |> Atom.to_string() |> String.split("-") |> Enum.at(0)
    table_name = Module.concat(cache_name, CachingModule.Pool)
    restart_counter = :ets.update_counter(table_name, pool_name, 1)
    unless restart_counter < @max_retry, do: stop_redis_pool(pool_name)
    :ok
  end

  @spec stop_redis_pool(String.t()) :: :ok | {:error, error}
        when error: :not_found | :simple_one_for_one | :running | :restarting
  def stop_redis_pool(pool_name) do
    Supervisor.terminate_child(__MODULE__, pool_name)
    Supervisor.delete_child(__MODULE__, pool_name)
  end
end
