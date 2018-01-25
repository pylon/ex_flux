defmodule Inflex.TestDatabase do
  @moduledoc false
  use Inflex.Database, otp_app: :inflex, database: "test"
end
