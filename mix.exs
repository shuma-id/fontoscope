defmodule Fontoscope.MixProject do
  use Mix.Project

  def project do
    [
      app: :fontoscope,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
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

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:sweet_xml, "~> 0.7.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_version, "~> 2.4.0", only: :dev, runtime: false}
    ]
  end
end
