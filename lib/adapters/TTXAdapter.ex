defmodule Fontoscope.TTXAdapter do
  @moduledoc """
  Wrapper for `ttx` console utility
  """
  use Fontoscope.Adapter, extensions: ~w(ttf otf woff woff2)

  import SweetXml

  alias Fontoscope.{FontInfo, CLI}

  # TODO: Change to some sort of typed enum?
  @type table_name :: String.t()

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    with {:ok, xml} <- tables(path, ~w(name OS/2)) do
      FontInfo.new(
        family: family_name(xml),
        foundry: foundry_name(xml),
        foundry_url: foundry_url(xml),
        weight: weight(xml)
      )
    end
  end

  @doc """
  Get tables from given file in XML format

  For more information about tables see:
  https://learn.microsoft.com/en-us/typography/opentype/spec/otff
  """
  @spec tables(Path.t(), [table_name()]) :: {:ok, SweetXml.xmlElement()} | {:error, String.t()}
  def tables(path, table_names) do
    table_names = Enum.map(table_names, &" -t #{&1} ")

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
    [21, 16, 18, 4, 1, 6]
    |> Stream.flat_map(&name_id_entries(xml, &1))
    |> Enum.at(0)
  end

  defp foundry_name(xml), do: first_name_id_entry(xml, 9)

  defp foundry_url(xml), do: first_name_id_entry(xml, 12)

  defp weight(xml) do
    case xpath(xml, ~x"//OS_2/usWeightClass/@value"sl) do
      [weight | _] -> String.to_integer(weight)
      _ -> 400
    end
  end

  defp first_name_id_entry(xml, name_id) do
    xml
    |> name_id_entries(name_id)
    |> Enum.at(0)
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
