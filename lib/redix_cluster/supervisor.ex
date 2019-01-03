defmodule RedixCluster.Supervisor do
  @moduledoc false

  use Supervisor

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
        id: Module.concat(cache_name, RedixCluster.Pools.Supervisor),
        start:
          {RedixCluster.Pools.Supervisor, :start_link,
           [[cache_name: cache_name, name: RedixCluster.Pools.Supervisor]]},
        type: :supervisor
      },
      %{
        id: Module.concat(cache_name, RedisCluster.Client.Monitor),
        start:
          {RedixCluster.Monitor, :start_link,
           [[cache_name: cache_name, name: RedixCluster.Monitor]]},
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
