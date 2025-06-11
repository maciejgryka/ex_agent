defmodule ExAgent.MixProject do
  use Mix.Project

  def project, do: [app: :ex_agent, version: "0.1.0", deps: deps()]
  def application, do: [extra_applications: [:logger], mod: {ExAgent.Application, []}]

  defp deps do
    [
      {:req, "~> 0.5.10"},
      {:jason, "~> 1.4"}
    ]
  end
end
