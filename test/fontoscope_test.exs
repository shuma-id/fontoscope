defmodule FontoscopeTest do
  use ExUnit.Case, async: true

  alias Fontoscope.FontInfo

  @fixtures_path "test/fixtures/fonts"

  defp fixture(path), do: Path.join(@fixtures_path, path)

  describe "extract/1 with corrupted files" do
    test "empty file returns eof error" do
      assert {:error, "File may be corrupted or empty"} =
               Fontoscope.extract(fixture("corrupted/empty.woff2"))
    end

    test "wrong signature returns format error" do
      assert {:error, "Can't detect file format by signature"} =
               Fontoscope.extract(fixture("corrupted/wrong_signature.woff2"))
    end

    test "signature only file returns ttx error" do
      assert {:error, _reason} = Fontoscope.extract(fixture("corrupted/signature_only.woff2"))
    end

    test "non-existent file returns error" do
      assert {:error, _reason} = Fontoscope.extract(fixture("does_not_exist.ttf"))
    end
  end

  describe "extract/1 format detection" do
    test "detects TTF format" do
      assert {:ok, %FontInfo{source_file_extension: :ttf}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.ttf"))
    end

    test "detects OTF format" do
      assert {:ok, %FontInfo{source_file_extension: :otf}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.otf"))
    end

    test "detects WOFF format" do
      assert {:ok, %FontInfo{source_file_extension: :woff}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.woff"))
    end

    test "detects WOFF2 format" do
      assert {:ok, %FontInfo{source_file_extension: :woff2}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.woff2"))
    end

    test "detects EOT format" do
      assert {:ok, %FontInfo{source_file_extension: :eot}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.eot"))
    end

    test "rejects SVG format" do
      assert {:error, "Can't detect file format by signature"} =
               Fontoscope.extract(fixture("blackout/blackout_midnight-webfont.svg"))
    end
  end

  describe "extract/1 format consistency" do
    test "ChunkFive-Regular returns same data across TTF, OTF, WOFF, WOFF2, EOT" do
      formats = ~w(ttf otf woff woff2 eot)

      results =
        formats
        |> Enum.map(&Fontoscope.extract(fixture("chunk/ChunkFive-Regular.#{&1}")))
        |> Enum.map(fn {:ok, info} -> info end)

      normalized = Enum.map(results, &%{&1 | source_file_extension: nil})

      assert [
               %{
                 family: "ChunkFive",
                 weight: %{
                   value: 400,
                   label: "Regular"
                 },
                 foundry: "The League of Moveable Type",
                 foundry_url: "http://www.theleagueofmoveabletype.com",
                 designer: "Meredith Mandel",
                 unique_identifier: %{
                   version: "2.001",
                   foundry_tag: "UKWN"
                 }
               }
             ] = Enum.uniq(normalized)
    end

    test "TheNeue-Black returns same data across TTF, OTF, WOFF, WOFF2" do
      formats = ~w(ttf otf woff woff2)

      results =
        formats
        |> Enum.map(&Fontoscope.extract(fixture("the_neue_black/TheNeue-Black.#{&1}")))
        |> Enum.map(fn {:ok, info} -> info end)

      normalized = Enum.map(results, &%{&1 | source_file_extension: nil})

      assert [%{
        family: "The Neue",
        weight: %{
          value: 900,
          label: "Black"
        }
      }] = Enum.uniq(normalized)
    end
  end

  describe "extract/1 weight detection" do
    test "Lato weight spectrum" do
      expectations = [
        {"Lato-Hairline.ttf", 250, "Extra Light"},
        {"Lato-Thin.ttf", 275, "Extra Light"},
        {"Lato-Light.ttf", 300, "Light"},
        {"Lato-Regular.ttf", 400, "Regular"},
        {"Lato-Medium.ttf", 500, "Medium"},
        {"Lato-Semibold.ttf", 600, "Semi Bold"},
        {"Lato-Bold.ttf", 700, "Bold"},
        {"Lato-Heavy.ttf", 800, "Extra Bold"},
        {"Lato-Black.ttf", 900, "Black"}
      ]

      for {file, expected_value, expected_label} <- expectations do
        {:ok, info} = Fontoscope.extract(fixture("lato/#{file}"))

        assert info.weight.value == expected_value,
               "#{file}: expected value #{expected_value}, got #{info.weight.value}"

        assert info.weight.label == expected_label,
               "#{file}: expected label #{expected_label}, got #{info.weight.label}"
      end
    end

    test "Acari Sans weight detection" do
      expectations = [
        {"AcariSans-Light.otf", 300, "Light"},
        {"AcariSans-Regular.otf", 400, "Regular"},
        {"AcariSans-Medium.otf", 500, "Medium"},
        {"AcariSans-SemiBold.otf", 600, "Semi Bold"},
        {"AcariSans-Bold.otf", 700, "Bold"},
        {"AcariSans-ExtraBold.otf", 400, "Regular"}, # Error in meta
        {"AcariSans-Black.otf", 400, "Regular"} # Error in meta
      ]

      for {file, expected_value, expected_label} <- expectations do
        {:ok, info} = Fontoscope.extract(fixture("acari_sans/#{file}"))

        assert info.weight.value == expected_value,
               "#{file}: expected value #{expected_value}, got #{info.weight.value}"

        assert info.weight.label == expected_label,
               "#{file}: expected label #{expected_label}, got #{info.weight.label}"
      end
    end

    test "Open Sans weight detection" do
      expectations = [
        {"OpenSans-Light.ttf", 300, "Light"},
        {"OpenSans-Regular.ttf", 400, "Regular"},
        {"OpenSans-Semibold.ttf", 600, "Semi Bold"},
        {"OpenSans-Bold.ttf", 700, "Bold"},
        {"OpenSans-ExtraBold.ttf", 800, "Extra Bold"}
      ]

      for {file, expected_value, expected_label} <- expectations do
        {:ok, info} = Fontoscope.extract(fixture("open_sans/#{file}"))

        assert info.weight.value == expected_value,
               "#{file}: expected value #{expected_value}, got #{info.weight.value}"

        assert info.weight.label == expected_label,
               "#{file}: expected label #{expected_label}, got #{info.weight.label}"
      end
    end
  end

  describe "extract/1 italic modifier" do
    test "detects italic from Lato" do
      assert {:ok, %{modifiers: []}} = Fontoscope.extract(fixture("lato/Lato-Regular.ttf"))

      assert {:ok, %{
        modifiers: ~w(italic)a,
        weight: %{label: "Regular Italic"}}} = Fontoscope.extract(fixture("lato/Lato-Italic.ttf"))

      assert {:ok, %{
        modifiers: ~w(italic)a,
        weight: %{label: "Bold Italic"}
      }} = Fontoscope.extract(fixture("lato/Lato-BoldItalic.ttf"))
    end

    test "detects italic from Open Sans" do
      assert {:ok, %{modifiers: []}} = Fontoscope.extract(fixture("open_sans/OpenSans-Regular.ttf"))
      assert {:ok, %{modifiers: ~w(italic)a}} = Fontoscope.extract(fixture("open_sans/OpenSans-Italic.ttf"))
    end

    test "detects italic from Acari Sans" do
      assert {:ok, %{modifiers: []}} = Fontoscope.extract(fixture("acari_sans/AcariSans-Regular.otf"))
      assert {:ok, %{modifiers: ~w(italic)a}} = Fontoscope.extract(fixture("acari_sans/AcariSans-Italic.otf"))
      assert {:ok, %{modifiers: ~w(italic)a}} = Fontoscope.extract(fixture("acari_sans/AcariSans-BoldItalic.otf"))
    end
  end

  describe "extract/1 variable fonts" do
    test "detects variable modifier from Acari Sans VF" do
      assert {:ok, %{modifiers: ~w(variable)a}} =
               Fontoscope.extract(fixture("acari_sans/AcariSans[wght].ttf"))

      assert {:ok, %{modifiers: ~w(variable italic)a}} =
               Fontoscope.extract(fixture("acari_sans/AcariSans-Italic[wght].ttf"))

      assert {:ok, %{modifiers: []}} =
               Fontoscope.extract(fixture("acari_sans/AcariSans-Regular.ttf"))
    end

    test "variable font has VF suffix in family name" do
      assert {:ok, %{family: "Acari Sans VF"}} = Fontoscope.extract(fixture("acari_sans/AcariSans[wght].ttf"))
      assert {:ok, %{family: "Acari Sans"}} = Fontoscope.extract(fixture("acari_sans/AcariSans-Regular.ttf"))
    end
  end

  describe "extract/1 font class" do
    test "Open Sans classified as sans_serif" do
      {:ok, %{class: :sans_serif}} = Fontoscope.extract(fixture("open_sans/OpenSans-Regular.ttf"))
    end

    test "Open Sans Bold classified as sans_serif" do
      {:ok, %{class: :sans_serif}} = Fontoscope.extract(fixture("open_sans/OpenSans-Bold.ttf"))
    end

    test "Open Sans Italic should be sans_serif too" do
      {:ok, %{class: :sans_serif}} = Fontoscope.extract(fixture("open_sans/OpenSans-Italic.ttf"))
    end

    test "Open Sans Semibold should be sans_serif too" do
      {:ok, %{class: :sans_serif}} = Fontoscope.extract(fixture("open_sans/OpenSans-Semibold.ttf"))
    end

    test "Lato is unclassified" do
      {:ok, %{class: :unclassified}} = Fontoscope.extract(fixture("lato/Lato-Regular.ttf"))
    end
  end

  describe "extract/1 metadata extraction" do
    test "ChunkFive has full metadata" do
      assert {:ok, %{
               foundry: "The League of Moveable Type",
               foundry_url: "http://www.theleagueofmoveabletype.com",
               designer: "Meredith Mandel",
               unique_identifier: %{
                 version: "2.001",
                 foundry_tag: "UKWN",
                 family: "ChunkFive-Regular"
               }
             }} = Fontoscope.extract(fixture("chunk/ChunkFive-Regular.ttf"))
    end

    test "Lato has foundry and designer but no unique_identifier" do
      assert {:ok, %{
               foundry: "tyPoland Lukasz Dziedzic",
               foundry_url: "http://www.typoland.com/",
               designer: "Lukasz Dziedzic with Adam Twardoch and Botio Nikoltchev",
               unique_identifier: nil
             }} = Fontoscope.extract(fixture("lato/Lato-Regular.ttf"))
    end

    test "Blackout has minimal metadata" do
      assert {:ok, %{
               family: "Blackout Midnight",
               foundry: nil,
               designer: nil,
               unique_identifier: nil
             }} = Fontoscope.extract(fixture("blackout/blackout_midnight-webfont.ttf"))
    end
  end

  describe "extract/1 family name sanitization" do
    test "removes weight suffix from family name" do
      assert {:ok, %{family: "The Neue"}} =
               Fontoscope.extract(fixture("the_neue_black/TheNeue-Black.ttf"))

      assert {:ok, %{family: "Lato"}} =
               Fontoscope.extract(fixture("lato/Lato-Bold.ttf"))
    end

    test "preserves family name with spaces" do
      assert {:ok, %{family: "ChunkFive Print"}} =
               Fontoscope.extract(fixture("chunk/Chunk Five Print.ttf"))
    end

    test "all Blackout variants have correct family names" do
      assert {:ok, %{family: "Blackout Midnight"}} =
               Fontoscope.extract(fixture("blackout/blackout_midnight-webfont.ttf"))

      assert {:ok, %{family: "Blackout Sunrise"}} =
               Fontoscope.extract(fixture("blackout/blackout_sunrise-webfont.ttf"))

      assert {:ok, %{family: "Blackout Two AM"}} =
               Fontoscope.extract(fixture("blackout/blackout_two_am-webfont.ttf"))
    end
  end

  describe "extract/1 EOT adapter" do
    test "extracts data from EOT files" do
      assert {:ok, %{family: "ChunkFive", source_file_extension: :eot}} =
               Fontoscope.extract(fixture("chunk/ChunkFive-Regular.eot"))
    end

    test "EOT returns same data as TTF" do
      {:ok, eot} = Fontoscope.extract(fixture("chunk/ChunkFive-Regular.eot"))
      {:ok, ttf} = Fontoscope.extract(fixture("chunk/ChunkFive-Regular.ttf"))

      assert %{family: family, weight: weight, foundry: foundry, designer: designer} = eot
      assert %{family: ^family, weight: ^weight, foundry: ^foundry, designer: ^designer} = ttf
    end

    test "Blackout EOT works" do
      assert {:ok, %{family: "Blackout Midnight", source_file_extension: :eot}} =
               Fontoscope.extract(fixture("blackout/blackout_midnight-webfont.eot"))
    end
  end
end
