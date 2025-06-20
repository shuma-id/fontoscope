defmodule Fontoscope do
  @moduledoc false

  alias Fontoscope.AdapterRegistry

  @doc """
  Extract font info from given file
  """
  @spec extract(String.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(file_path) do
    extension = get_extension(file_path)

    with {:ok, adapter} <- AdapterRegistry.find_by_extension(extension),
         {:ok, font_info} <- adapter.extract(file_path) do
      {:ok, font_info}
    end
  end

  defp get_extension(file_path) do
    file_path
    |> Path.extname()
    |> String.downcase()
    |> String.trim_leading(".")
  end

end
