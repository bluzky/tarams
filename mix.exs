defmodule Tarams.MixProject do
  use Mix.Project

  def project do
    [
      app: :tarams,
      version: "1.5.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
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
    "Phoenix request params validation library"
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
      {:valdi, "~> 0.2.0"},
      {:ex_doc, "~> 0.27", only: [:dev]},
      {:excoveralls, "~> 0.14", only: :test},
      {:decimal, "~> 2.0"}
    ]
  end
end
