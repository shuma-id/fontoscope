defmodule Fontoscope do
  @moduledoc false

  alias Fontoscope.{AdapterRegistry, FontInfo}

  @type opts :: [{:after, (Path.t() -> any())}]

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t(), opts()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(file_path, opts \\ []) do
    result = do_extract(file_path)
    run_callbacks(file_path, opts)
    result
  end

  defp do_extract(file_path) do
    with {:ok, extension} <- detect_extension_by_signature(file_path),
         {:ok, adapter} <- AdapterRegistry.find_by_extension(extension),
         {:ok, font_info} <- adapter.extract(file_path) do
      {:ok, put_extension(font_info, extension)}
    end
  end

  defp detect_extension_by_signature(file_path) do
    case read_first_bytes(file_path, 36) do
      {:ok, <<0x77, 0x4F, 0x46, 0x46, _rest::binary>>} -> {:ok, "woff"}
      {:ok, <<0x77, 0x4F, 0x46, 0x32, _rest::binary>>} -> {:ok, "woff2"}
      {:ok, <<0x00, 0x01, 0x00, 0x00, 0x00, _rest::binary>>} -> {:ok, "ttf"}
      {:ok, <<0x4F, 0x54, 0x54, 0x4F, _rest::binary>>} -> {:ok, "otf"}
      {:ok, <<_first::binary-size(34), 0x4C, 0x50, _rest::binary>>} -> {:ok, "eot"}
      {:ok, _bytes} -> {:error, "Can't detect file format by signature"}
      error -> error
    end
  end

  defp read_first_bytes(file_path, bytes) do
    with {:ok, file} <- File.open(file_path),
         {:ok, first_bytes} <- :file.read(file, bytes) do
      File.close(file)
      {:ok, first_bytes}
    else
      {:error, reason} -> {:error, "Failed to read file: #{inspect(reason)}"}
      :eof -> {:error, "File may be corrupted or empty"}
    end
  end

  defp put_extension(font_info, extension) do
    case FontInfo.cast_extension(extension) do
      {:ok, ext} -> %{font_info | source_file_extension: ext}
      :error -> font_info
    end
  end

  defp run_callbacks(file_path, opts) do
    Enum.each(opts, fn
      {:after, callback} -> callback.(file_path)
      _ -> nil
    end)
  end
end
