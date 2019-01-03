use Mix.Config

# You can configure for your application as:
#
# copy from redix.ex
# `connection_opts` is a list of options used to manage the connection. These
#  are the Redix-specific options that can be used:

#   * `:socket_opts` - (list of options) this option specifies a list of options
#      that are passed to `:gen_tcp.connect/4` when connecting to the Redis
#      server. Some socket options (like `:active` or `:binary`) will be
#      overridden by Redix so that it functions properly. Defaults to `[]`.
#   * `:backoff` - (integer) the time (in milliseconds) to wait before trying to
#      reconnect when a network error occurs. Defaults to `2000`.
#   * `:max_reconnection_attempts` - (integer or `nil`) the maximum number of
#      reconnection attempts that the Redix process is allowed to make. When the
#      Redix process "consumes" all the reconnection attempts allowed to it, it
#      will exit with the original error's reason. If the value is nil, there's
#      no limit to the reconnection attempts that can be made. Defaults to nil.

config :redix_cluster,
  cluster_nodes: [
    %{host: "staging.lygt2n.clustercfg.use1.cache.amazonaws.com", port: 6379}
  ],
  pool_size: 5,
  pool_max_overflow: 0,

  # connection_opts
  socket_opts: [],
  backoff: 2000,
  max_reconnection_attempts: nil
