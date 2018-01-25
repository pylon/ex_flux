defmodule Inflex.Application do
  @moduledoc """
  Inflex's per-node registry within the library's exported application

  Inflex uses `Registry` to support database-name-based dispatch as a primary
  design goal was multi-tenancy or sharding support for non-enterprise use
  cases.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Registry, [:unique, Inflex.Registry])
    ]

    opts = [strategy: :one_for_one, name: Inflex.Application]

    Supervisor.start_link(children, opts)
  end
end
