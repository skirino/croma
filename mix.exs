defmodule Croma.Mixfile do
  use Mix.Project

  def project do
    [
      app:             :croma,
      version:         "0.3.3",
      elixir:          "~> 1.0",
      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps:            deps,
      description:     description,
      package:         package,
      source_url:      "https://github.com/skirino/croma",
      homepage_url:    "https://github.com/skirino/croma",
      test_coverage:   [tool: Coverex.Task, coveralls: true],
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:excheck, "~> 0.2", only: :test},
      {:triq, github: "krestenkrab/triq", only: :test},
      {:coverex, "~> 1.4", only: :test},
      {:dialyze, "~> 0.2", only: :dev},
      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.7", only: :dev},
      {:inch_ex, only: :docs},
    ]
  end

  defp description do
    """
    Elixir macro utilities
    """
  end

  defp package do
    [
      files:       ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Shunsuke Kirino"],
      licenses:    ["MIT"],
      links:       %{"GitHub repository" => "https://github.com/skirino/croma", "Doc" => "http://hexdocs.pm/croma/"},
    ]
  end
end
