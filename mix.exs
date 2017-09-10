defmodule SubgRfspy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :subg_rfspy,
      version: "0.9.0",
      elixir: ">= 1.4.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "SubgRfspy",
      source_url: "https://github.com/infinity-aps/elixir_subg_rfspy",
      description: description(),
      package: package()
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

  defp description do
    """
    SubgRfspy is a library to handle sub-GHz wireless packet communication via a TI cc1110 chip running subg_rfspy.
    """
  end

  defp package do
    [
      maintainers: ["Timothy Mecklem"],
      licenses: ["MIT License"],
      links: %{"Github" => "https://github.com/infinity-aps/elixir_subg_rfspy"}
    ]
  end
end
