defmodule Croma.Mixfile do
  use Mix.Project

  @github_url "https://github.com/skirino/croma"

  def project do
    [
      app:             :croma,
      version:         "0.6.8",
      elixir:          "~> 1.4",
      build_embedded:  Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps:            deps(),
      description:     "Elixir macro utilities",
      package:         package(),
      source_url:      @github_url,
      homepage_url:    @github_url,
      test_coverage:   [tool: Coverex.Task, coveralls: true],
    ]
  end

  def application() do
    []
  end

  defp deps() do
    [
      {:excheck, "~> 0.5", only: :test},
      {:triq, github: "triqng/triq", only: :test},
      {:coverex, "~> 1.4", only: :test},
      {:dialyze, "~> 0.2", only: :dev},
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.16", only: :dev},
      {:inch_ex, "~> 0.5", only: :docs},
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
