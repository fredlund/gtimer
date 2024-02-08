defmodule Gtimer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :gtimer,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  defp package do
    [
      licenses: ["BSD-3-Clause"],
      links: %{},
      description: "A small library which provides a global timer facility in Elixir (or Erlang)"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:epqueue, "~> 1.2"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
