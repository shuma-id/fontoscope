defmodule Fontoscope.TTXAdapter do
  @moduledoc """
  Wrapper for `ttx` console utility
  """
  use Fontoscope.Adapter, extensions: ~w(ttf otf woff woff2)

  import SweetXml

  alias Fontoscope.{FontInfo, CLI}

  @type table_name :: String.t()

  @doc """
  Extract font info from given file
  """
  @spec extract(String.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    with {:ok, xml} <- tables(path, ~w(name OS/2)) do
      foundry_id = 9
      foundry_url_id = 12

      FontInfo.new(
        family: family_name(xml),
        foundry: first_name_id_entry(xml, foundry_id),
        foundry_url: first_name_id_entry(xml, foundry_url_id),
        weight: weight(xml)
      )
    end
  end

  @doc """
  Get tables from given file in XML format

  For more information about tables see:
  https://learn.microsoft.com/en-us/typography/opentype/spec/otff
  """
  @spec tables(String.t(), [table_name()]) :: {:ok, SweetXml.xmlElement()} | {:error, String.t()}
  def tables(path, table_names) do
    table_names = table_names |> Enum.map(&"-t #{&1}") |> Enum.join(" ")

    args = ~w(-q -o - #{table_names} #{path})

    CLI.cmd "ttx", args, [stderr_to_stdout: true],
      do: &parse_xml/1,
      else: &make_error/1
  end

  defp parse_xml(content) do
    try do
      {:ok, SweetXml.parse(content)}
    rescue
      _ -> {:error, "Failed to parse XML"}
    end
  end

  defp family_name(xml) do
    # nameID='21' is WWS family name
    # nameID='16' is preferred family name
    # nameID='18' is compatible full macintosh family name
    # nameID='4' is full font name
    # nameID='1' is common family name
    # nameID='6' is PostScript name
    Enum.concat([
      name_id_entries(xml, 21),
      name_id_entries(xml, 16),
      name_id_entries(xml, 18),
      name_id_entries(xml, 4),
      name_id_entries(xml, 1),
      name_id_entries(xml, 6)
    ])
    |> List.first()
  end

  defp first_name_id_entry(xml, name_id) do
    xml
    |> name_id_entries(name_id)
    |> List.first()
  end

  defp weight(xml) do
    case xpath(xml, ~x"//OS_2/usWeightClass/@value"sl) do
      [weight | _] -> String.to_integer(weight)
      _ -> 400
    end
  end

  defp name_id_entries(xml, name_id) do
    xml
    |> xpath(~x"//namerecord[@nameID='#{name_id}']/text()"sl)
    |> Enum.map(&String.trim(&1))
    |> Enum.reject(&(&1 == ""))
  end

  # We can't disable large help that always printed before the error message
  # So this function extracts actual error message from ttx output
  defp make_error(output) do
    case Regex.run(~r/ERROR: (.+)$/, output) do
      nil -> {:error, "Unknown TTX error"}
      [_, error] -> {:error, String.trim(error)}
    end
  end

end
