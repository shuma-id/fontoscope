defmodule Fontoscope.CLI do
  @moduledoc false

  def cmd(cmd, args, opts \\ [], do: on_success, else: on_error) do
    case System.cmd(cmd, args, opts) do
      {content, 0} -> on_success.(content)
      {error, _} -> on_error.(error)
    end
  end
end
