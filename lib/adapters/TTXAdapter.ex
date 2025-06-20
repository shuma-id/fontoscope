defmodule Fontoscope.TTXAdapter do
  @moduledoc """
  Wrapper for `ttx` console utility
  """
  use Fontoscope.Adapter, extensions: ~w(ttf otf woff woff2)

  import SweetXml

  @type table_name :: String.t()

  @doc """
  Extract font info from given file
  """
  @spec extract(String.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    with {:ok, xml_meta} <- tables(path, ~w(name OS/2)) do
      foundry_id = 9
      foundry_url_id = 12

      info = FontInfo.new(%{
        family: family_name(xml_meta),
        foundry: first_name_id_entry(xml_meta, foundry_id),
        foundry_url: first_name_id_entry(xml_meta, foundry_url_id),
        weight: weight(xml_meta)
      })

      {:ok, info}
    end
  end

  @doc """
  Get tables from given file
  """
  @spec tables(String.t(), [table_name()]) :: {:ok, String.t()} | {:error, String.t()}
  def tables(path, table_names) do
    table_names = table_names |> Enum.map(&"-t #{&1}") |> Enum.join(" ")

    args = ~w(-q -o - #{table_names} #{path})

    case System.cmd("ttx", args, stderr_to_stdout: true) do
      {content, 0} -> {:ok, to_string(content)}
      {error, _} -> {:error, error_message(error)}
    end
  end

  defp family_name(xml_meta) do
    # nameID='21' is WWS family name
    # nameID='16' is preferred family name
    # nameID='18' is compatible full macintosh family name
    # nameID='4' is full font name
    # nameID='1' is common family name
    Enum.concat([
      name_id_entries(xml_meta, 21),
      name_id_entries(xml_meta, 16),
      name_id_entries(xml_meta, 18),
      name_id_entries(xml_meta, 4),
      name_id_entries(xml_meta, 1)
    ])
    |> List.first()
  end

  defp first_name_id_entry(xml_meta, name_id) do
    xml_meta
    |> name_id_entries(name_id)
    |> List.first()
  end

  defp weight(xml_meta) do
    case xpath(xml_meta, ~x"//OS_2/usWeightClass/@value"sl) do
      [weight | _] -> String.to_integer(weight)
      _ -> 400
    end
  end

  defp name_id_entries(xml_meta, name_id) do
    xml_meta
    |> xpath(~x"//namerecord[@nameID='#{name_id}']/text()"sl)
    |> Enum.map(&String.trim(&1))
    |> Enum.reject(&(&1 == ""))
  end

  # We can't disable large help that always printed before the error message
  # So this function extracts actual error message from ttx output
  defp error_message(output) do
    case Regex.run(~r/ERROR: (.+)$/, output) do
      nil -> ""
      [_, error] -> String.trim(error)
    end
  end

end
