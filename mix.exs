defmodule Croma.Mixfile do
  use Mix.Project

  @github_url "https://github.com/skirino/croma"

  def project() do
    [
      app:               :croma,
      version:           "0.12.0",
      elixir:            "~> 1.7",
      build_embedded:    Mix.env() == :prod,
      start_permanent:   Mix.env() == :prod,
      deps:              deps(),
      description:       "Elixir macro utilities to make type-based programming easier",
      package:           package(),
      source_url:        @github_url,
      homepage_url:      @github_url,
      test_coverage:     [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
    ]
  end

  def application() do
    if Mix.env() == :dev, do: [extra_applications: [:mix]], else: []
  end

  defp deps() do
    [
      {:dialyxir   , "~> 1.4" , [only: :dev , runtime: false]},
      {:ex_doc     , "~> 0.37", [only: :dev , runtime: false]},
      {:stream_data, "~> 1.1" , [only: :test]},
      {:excoveralls, "~> 0.18", [only: :test, runtime: false]},
    ]
  end

  defp package() do
    [
      files:       ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Shunsuke Kirino"],
      licenses:    ["MIT"],
      links:       %{"GitHub repository" => @github_url},
    ]
  end
end
