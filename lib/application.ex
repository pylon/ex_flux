defmodule ExFlux.Application do
  @moduledoc """
  ExFlux's per-node registry within the library's exported application

  ExFlux uses `Registry` to support database-name-based dispatch as a primary
  design goal was multi-tenancy or sharding support for non-enterprise use
  cases.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Registry, [:unique, ExFlux.Registry])
    ]

    opts = [strategy: :one_for_one, name: ExFlux.Application]

    Supervisor.start_link(children, opts)
  end
end
