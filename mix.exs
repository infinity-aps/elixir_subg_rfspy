defmodule SubgRfspy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :subg_rfspy,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:nerves_uart, "~> 0.1.1"},
     {:csv, "~> 2.0.0"},
     {:credo, "~> 0.8", only: [:dev, :test], runtime: false}]
  end
end
