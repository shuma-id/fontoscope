defmodule Fontoscope.TTXAdapter do
  @moduledoc """
  Wrapper for `ttx` console utility
  """
  use Fontoscope.Adapter, extensions: ~w(ttf otf woff woff2)

  import SweetXml

  alias Fontoscope.{CLI, FontInfo, Weight}

  @type table_name :: String.t()

  @doc """
  Extract font info from given file
  """
  @spec extract(Path.t()) :: {:ok, FontInfo.t()} | {:error, String.t()}
  def extract(path) do
    with {:ok, xml} <- tables(path, ~w(name fvar OS/2)),
         {:ok, weight} <- weight(xml) do
      FontInfo.new(
        family: sanitized_family_name(xml),
        foundry: foundry_name(xml),
        foundry_url: foundry_url(xml),
        designer: designer_name(xml),
        weight: weight,
        modifiers: modifiers(xml),
        class: class(xml),
        unique_identifier: unique_identifier(xml)
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
    sanitized_content = sanitize_xml(content)

    try do
      {:ok, SweetXml.parse(sanitized_content)}
    rescue
      error -> {:error, "Failed to parse XML: #{inspect(error)}"}
    catch
      kind, reason -> {:error, "Failed to parse XML: #{inspect(kind)} #{inspect(reason)}"}
    end
  end

  # Remove invalid characters from XML content
  # According to XML 1.0 specification (https://www.w3.org/TR/xml/#charsets)
  defp sanitize_xml(content) do
    content
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
    |> ensure_utf8()
  end

  defp ensure_utf8(content) do
    case :unicode.characters_to_binary(content, :utf8, :utf8) do
      {:error, _, _} -> ""
      {:incomplete, _, _} -> ""
      valid_utf8 -> valid_utf8
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
    |> Enum.flat_map(&name_id_entries(xml, &1))
    |> Enum.at(0, "")
    |> trim_non_word_characters()
  end

  defp trim_non_word_characters(name) do
    name
    |> String.replace(~r/^\W+|\W+$/u, "")
  end

  defp sanitized_family_name(xml) do
    keywords =
      weight_labels()
      |> Enum.concat(["Italic"])
      |> Enum.sort_by(&String.length/1, :desc)

    xml
    |> family_name()
    |> remove_weight_keywords(keywords)
    |> trim_separators()
  end

  defp remove_weight_keywords(name, keywords) do
    Enum.reduce_while(keywords, name, fn keyword, current_name ->
      pattern = ~r/#{Regex.escape(keyword)}$/i

      if String.match?(current_name, pattern) do
        new_name = String.replace(current_name, pattern, "") |> String.trim()
        {:halt, remove_weight_keywords(new_name, keywords)}
      else
        {:cont, current_name}
      end
    end)
  end

  defp trim_separators(name) do
    name
    |> String.replace(~r/[\s_-]+$/, "")
    |> String.trim()
  end

  defp foundry_name(xml), do: first_name_id_entry(xml, 8)

  defp designer_name(xml), do: first_name_id_entry(xml, 9)

  defp foundry_url(xml), do: first_name_id_entry(xml, 11)

  defp unique_identifier(xml) do
    xml
    |> name_id_entries(3)
    |> Enum.map(&String.split(&1, ";"))
    |> List.first([])
    |> Enum.zip(~w(version foundry_tag family)a)
    |> Map.new(fn {val, key} -> {key, String.trim(val)} end)
    |> then(fn id -> if Enum.empty?(id), do: nil, else: id end)
  end

  defp weight(xml) do
    family_name = family_name(xml)
    value = weight_value(xml)
    target_labels = weight_labels()
    is_italic = italic?(xml)

    regex = ~r/[\s_-]+(#{Enum.join(target_labels, "|")})[\s_-]*$/i

    label =
      case Regex.run(regex, family_name) do
        [_, label] -> label
        _ -> List.first(weight_label(value))
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
    |> Enum.map_join(" ", &String.capitalize/1)
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
        weight < 400 -> ["light", "semi light"]
        weight < 500 -> ["regular", "normal"]
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

  defp modifiers(xml) do
    %{italic: italic?(xml), variable: variable?(xml)}
    |> Map.filter(fn {_k, v} -> v end)
    |> Map.keys()
  end

  defp variable?(xml) do
    case xpath(xml, ~x"//fvar") do
      nil -> false
      _ -> true
    end
  end

  defp italic?(xml) do
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

  # Fetch all text entries for the given `name_id` and sort them according
  # to preferred `platformID`s. Some fonts contain several records for the
  # same `nameID` that differ only by `platformID`.
  #
  # The OpenType specification does not define an official priority order, so
  # we establish one that works best in practice:
  #   1. Unicode     – `platformID = 0`
  #   2. Windows     – `platformID = 3`
  #   3. Macintosh   – `platformID = 1`
  defp name_id_entries(xml, name_id) do
    xml
    |> xpath(~x"//namerecord[@nameID='#{name_id}']"l, name: ~x"./text()"s, platform: ~x"@platformID"i)
    |> sort_by_platform()
    |> Enum.map(fn %{name: name} -> String.trim(name) end)
    |> Enum.reject(&(&1 == ""))
  end

  defp sort_by_platform(entries) do
    preferred_platform_order = [0, 3, 1]
    Enum.sort_by(entries, fn %{platform: platform} ->
      Enum.find_index(preferred_platform_order, &(&1 == platform))
    end, :desc)
  end

  defp class(xml) do
    case xpath(xml, ~x"//OS_2/sFamilyClass/@value"sl) do
      [value | _] ->
        value
        |> String.to_integer()
        |> get_class()
      _ ->
        :unclassified
    end
  end

  defp get_class(class_value) do
    # Extract the high byte (font class) from the 16-bit value
    class = div(class_value, 256)

    case class do
      1 -> :oldstyle_serif
      2 -> :transitional_serif
      3 -> :modern_serif
      4 -> :clarendon_serif
      5 -> :slab_serif
      7 -> :freeform_serif
      8 -> :sans_serif
      9 -> :ornamental
      10 -> :script
      12 -> :symbolic
      _ -> :unclassified
    end
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
