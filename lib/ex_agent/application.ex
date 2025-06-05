defmodule ExAgent.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExAgent, []}
    ]

    opts = [strategy: :one_for_one, name: ExAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end
end