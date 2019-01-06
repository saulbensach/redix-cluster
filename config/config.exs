use Mix.Config

config :redix_cluster,
  cluster_nodes: [
    %{host: "staging.lygt2n.clustercfg.use1.cache.amazonaws.com", port: 6379}
  ],
  pool_size: 5,
  pool_max_overflow: 0
