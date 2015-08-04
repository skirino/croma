defmodule Croma.Mixfile do
  use Mix.Project

  def project do
    [
      app:             :croma,
      version:         "0.1.4",
      elixir:          "~> 1.0",
      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps:            deps,
      description:     description,
      package:         package,
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:excheck, "~> 0.2", only: :test},
      {:triq, github: "krestenkrab/triq", only: :test},
    ]
  end

  defp description do
    """
    Elixir macro utilities
    """
  end

  defp package do
    [
      files:        ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Shunsuke Kirino"],
      licenses:     ["MIT"],
      links:        %{"GitHub repository" => "https://github.com/skirino/croma"},
    ]
  end
end
