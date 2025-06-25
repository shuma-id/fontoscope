defmodule Fontoscope do
  @moduledoc false

  alias Fontoscope.{AdapterRegistry, FontInfo}

  @type opts :: [{:after, (Path.t() -> any())}]

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t(), opts()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(file_path, opts \\ []) do
    extension = get_extension(file_path)

    result =
      with {:ok, adapter} <- AdapterRegistry.find_by_extension(extension) do
        adapter.extract(file_path)
      end

    run_callbacks(file_path, opts)

    result
  end

  defp get_extension(file_path) do
    file_path
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
  end

  defp run_callbacks(file_path, opts) do
    Enum.each(opts, fn
      {:after, callback} -> callback.(file_path)
      _ -> nil
    end)
  end

end
