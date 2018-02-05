defmodule ExFlux.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_flux,
      version: "0.1.1",
      description: "InfluxDB driver for Elixir",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        source_url: "https://github.com/pylon/ex_flux",
        extras: ["README.md"]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.post": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExFlux.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:poolboy, "~> 1.5"},
      {:credo, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:excoveralls, "~> 0.8", only: :test},
      {:dialyxir, "~> 0.5", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["mix.exs", "README.md", "lib"],
      maintainers: ["Neil Menne, Noel Weichbrodt"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/pylon/ex_flux",
        "Docs" => "http://hexdocs.pm/ex_flux/"
      }
    ]
  end
end
