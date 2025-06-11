defmodule ExAgent.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args), do: Supervisor.start_link([ExAgent], strategy: :one_for_one)
end
