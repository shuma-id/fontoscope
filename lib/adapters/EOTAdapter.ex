defmodule Fontoscope.EOTAdapter do
  @moduledoc """
  Adapter for EOT files
  """
  use Fontoscope.Adapter, extensions: ~w(eot)

  alias Fontoscope.{FontInfo, TTXAdapter}

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    parse_eot_file(path)
  end

  defp parse_eot_file(eot_path) do
    with_temp_file("", "ttf", fn ttf_path ->
      args = ~w(#{eot_path} #{ttf_path})

      case System.cmd("eot2ttf", args, stderr_to_stdout: true) do
        {_, 0} -> TTXAdapter.extract(ttf_path)
        {error, _} -> {:error, error}
      end
    end)
  end

  defp with_temp_file(content, extension, function) do
    temp_path = Path.join(
      System.tmp_dir(),
      "font_meta_#{:erlang.unique_integer([:positive])}.#{extension}"
    )

    File.write!(temp_path, content)

    result = function.(temp_path)

    File.rm!(temp_path)

    result
  end

end
