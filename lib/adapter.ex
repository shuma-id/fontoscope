defmodule Fontoscope.Adapter do
  @moduledoc false

  @type file_path :: String.t() | Path.t()

  @callback extract(file_path()) :: {:ok, FontInfo.t()} | {:error, String.t()}

  defmacro __using__(opts) do
    extensions = Keyword.fetch!(opts, :extensions)

    quote do
      @behaviour Fontoscope.Adapter

      @supported_extensions unquote(extensions)

      def supported_extensions, do: @supported_extensions
    end
  end

end
