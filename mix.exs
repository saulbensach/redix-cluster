defmodule RedixCluster.Mixfile do
  use Mix.Project

  def project do
    [
      app: :redix_cluster,
      version: "0.0.1",
      elixir: "~> 1.1",
      build_embedded: Mix.env() in [:prod],
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [espec: :test],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env())
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remixed_remix]
  defp applications(_all), do: [:logger, :runtime_tools]

  defp deps do
    [
      {:redix, ">= 0.0.0"},
      {:poolboy, "~> 1.5"},
      {:remixed_remix, "~> 1.0.0", only: :dev}
    ]
  end
end
