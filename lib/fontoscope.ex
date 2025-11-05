defmodule Fontoscope do
  @moduledoc false

  alias Fontoscope.{AdapterRegistry, FontInfo}

  @type opts :: [{:after, (Path.t() -> any())}]

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t(), opts()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(file_path, opts \\ []) do
    with {:ok, adapter} <- find_adapter(file_path) do
      result = adapter.extract(file_path)
      run_callbacks(file_path, opts)
      result
    end
  end

  defp find_adapter(file_path) do
    with {:ok, extension} <- detect_extension_by_signature(file_path) do
      AdapterRegistry.find_by_extension(extension)
    end
  end

  defp detect_extension_by_signature(file_path) do
    with {:ok, file} <- File.open(file_path) do
      first_bytes = :file.read(file, 36)
      File.close(file)
      dispatch_by_signature(first_bytes)
    end
  end

  defp dispatch_by_signature({:ok, first_bytes}) do
    case first_bytes do
      <<0x77, 0x4F, 0x46, 0x46, _rest::binary>> -> {:ok, "woff"}
      <<0x77, 0x4F, 0x46, 0x32, _rest::binary>> -> {:ok, "woff2"}
      <<0x00, 0x01, 0x00, 0x00, 0x00, _rest::binary>> -> {:ok, "ttf"}
      <<0x4F, 0x54, 0x54, 0x4F, _rest::binary>> -> {:ok, "otf"}
      <<_first::binary-size(34), 0x4C, 0x50, _rest::binary>> -> {:ok, "eot"}
      _ -> {:error, "Unsupported file format"}
    end
  end

  defp dispatch_by_signature(:eof), do: {:error, "File may be corrupted or empty"}
  defp dispatch_by_signature({:error, reason}), do: {:error, "Failed to read file: #{reason}"}

  defp run_callbacks(file_path, opts) do
    Enum.each(opts, fn
      {:after, callback} -> callback.(file_path)
      _ -> nil
    end)
  end
end
