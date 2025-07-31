defmodule Fontoscope do
  @moduledoc false

  alias Fontoscope.{AdapterRegistry, FontInfo}

  @type opts :: [{:after, (Path.t() -> any())}]

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t(), opts()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(file_path, opts \\ []) do
    extension = detect_extension(file_path)

    result = do_extract(file_path, extension)

    run_callbacks(file_path, opts)

    result
  end

  defp do_extract(file_path, extension) do
    with {:ok, adapter} <- AdapterRegistry.find_by_extension(extension) do
      adapter.extract(file_path)
    end
  end

  defp detect_extension(file_path) do
    extension = get_extension_from_path(file_path)

    if extension in AdapterRegistry.supported_extensions() do
      extension
    else
      get_extension_by_signature(file_path)
    end
  end

  defp get_extension_from_path(file_path) do
    file_path
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
  end

  defp get_extension_by_signature(file_path) do
    first_bytes = File.stream!(file_path, 36) |> Enum.at(0)

    case first_bytes do
      <<0x77, 0x4F, 0x46, 0x46, _rest::binary>> -> "woff"
      <<0x77, 0x4F, 0x46, 0x32, _rest::binary>> -> "woff2"
      <<0x00, 0x01, 0x00, 0x00, 0x00, _rest::binary>> -> "ttf"
      <<0x4F, 0x54, 0x54, 0x4F, _rest::binary>> -> "otf"
      <<_first::binary-size(34), 0x4C, 0x50, _rest::binary>> -> "eot"
      _ -> nil
    end
  end

  defp run_callbacks(file_path, opts) do
    Enum.each(opts, fn
      {:after, callback} -> callback.(file_path)
      _ -> nil
    end)
  end

end
