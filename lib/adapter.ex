defmodule Fontoscope.Adapter do
  @moduledoc false

  alias Fontoscope.FontInfo

  @callback extract(Path.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  @callback supported_extensions() :: [String.t(), ...]

  defmacro __using__(opts) do
    extensions = Keyword.fetch!(opts, :extensions)

    quote do
      @behaviour Fontoscope.Adapter

      @supported_extensions unquote(extensions)

      def supported_extensions, do: @supported_extensions
    end
  end
end
