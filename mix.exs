defmodule Tarams.MixProject do
  use Mix.Project

  def project do
    [
      app: :tarams,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Tarams",
      description: description(),
      source_url: "https://github.com/bluzky/tarams",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      maintainers: ["Dung Nguyen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bluzky/tarams"}
    ]
  end

  defp description() do
    "Simplest library to parse and validate parameters in elixir "
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:ex_doc, "~> 0.22.1", only: [:dev]}
    ]
  end
end
