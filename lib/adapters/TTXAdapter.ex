defmodule Fontoscope.TTXAdapter do
  @moduledoc """
  Wrapper for `ttx` console utility
  """
  use Fontoscope.Adapter, extensions: ~w(ttf otf woff woff2)

  import SweetXml

  alias Fontoscope.{FontInfo, CLI, Weight}

  # TODO: Change to some sort of typed enum?
  @type table_name :: String.t()

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    with {:ok, xml} <- tables(path, ~w(name OS/2)),
         {:ok, weight} <- weight(xml) do
      FontInfo.new(
        family: sanitized_family_name(xml),
        foundry: foundry_name(xml),
        foundry_url: foundry_url(xml),
        designer: designer_name(xml),
        weight: weight,
        is_italic: is_italic(xml)
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
    catch
      _kind, _reason -> {:error, "Failed to parse XML"}
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

  defp sanitized_family_name(xml) do
    kw_group =
      weight_labels()
      |> Enum.concat(["Italic"])
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.map(&Regex.escape/1)
      |> Enum.join("|")

    # matches first weight keyword till the end, including chained ones
    pattern = ~r/[\s_-]+(?:#{kw_group})(?:[\s_-]+(?:#{kw_group}))*$/iu

    xml
    |> family_name()
    |> String.replace(pattern, "")
    |> String.trim()
  end

  defp foundry_name(xml), do: first_name_id_entry(xml, 8)

  defp designer_name(xml), do: first_name_id_entry(xml, 9)

  defp foundry_url(xml), do: first_name_id_entry(xml, 11)

  defp weight(xml) do
    family_name = family_name(xml)
    value = weight_value(xml)
    target = weight_label(value)
    is_italic = is_italic(xml)

    regex = ~r/[\s_-]+(#{Enum.join(target, "|")})[\s_-]*$/i

    label =
      case Regex.run(regex, family_name) do
        [_, label] -> label
        _ -> "Regular"
      end
      |> sanitize_weight_label()
      |> add_italic_suffix(is_italic)

    Weight.new(label: label, value: value)
  end

  defp weight_value(xml) do
    case xpath(xml, ~x"//OS_2/usWeightClass/@value"sl) do
      [weight | _] -> String.to_integer(weight)
      _ -> 400
    end
  end

  defp add_italic_suffix(label, false), do: label
  defp add_italic_suffix(label, true), do: "#{label} Italic"

  defp sanitize_weight_label(label) do
    label
    |> String.trim()
    |> split_compound_label()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp split_compound_label(text) do
    text
    |> String.replace(~r/semi([a-z])/i, "semi \\1")
    |> String.replace(~r/demi([a-z])/i, "demi \\1")
    |> String.replace(~r/extra([a-z])/i, "extra \\1")
    |> String.replace(~r/ultra([a-z])/i, "ultra \\1")
    |> String.split(~r/[\s_-]+/)
  end

  defp weight_labels do
    100..1000//100
    |> Enum.map(&weight_label/1)
    |> List.flatten()
  end

  defp weight_label(weight) do
    base_labels =
      cond do
        weight < 200 -> ["thin", "hairline"]
        weight < 300 -> ["extra light", "ultra light"]
        weight < 400 -> ["light"]
        weight < 500 -> ["normal", "regular"]
        weight < 600 -> ["medium"]
        weight < 700 -> ["semi bold", "demi bold"]
        weight < 800 -> ["bold"]
        weight < 900 -> ["extra bold", "ultra bold"]
        weight < 950 -> ["black", "heavy"]
        weight >= 950 -> ["extra black", "ultra black"]
      end

    base_labels
    |> Enum.flat_map(&expand_weight_variants/1)
    |> Enum.uniq()
  end

  defp expand_weight_variants(label) do
    if String.contains?(label, " ") do
      [
        label,
        String.replace(label, " ", "-"),
        String.replace(label, " ", "")
      ]
    else
      [label]
    end
  end

  defp is_italic(xml) do
    with [value | _] <- xpath(xml, ~x"//OS_2/fsSelection/@value"sl),
         value <- String.replace(value, " ", ""),
         {num, _} <- Integer.parse(value, 2) do
      Bitwise.band(num, 1) == 1
    else
      _ -> false
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
