defmodule Fontoscope.MixProject do
  use Mix.Project

  def project do
    [
      app: :fontoscope,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: [:domo_compiler] ++ Mix.compilers(),
      deps: deps(),
      versioning: versioning()
    ]
  end

  defp versioning do
    [
      tag_prefix: "release-",
      commit_message: "release: v%s",
      annotation: "tag release-%s created with mix version",
      annotate: true
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
      {:sweet_xml, "~> 0.7.5"},
      {:domo, "~> 1.5.17"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_version, "~> 2.4.0", only: :dev, runtime: false}
    ]
  end
end
