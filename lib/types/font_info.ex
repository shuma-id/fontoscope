defmodule Fontoscope.FontInfo do
  @moduledoc false

  alias Fontoscope.FontInfo
  alias Fontoscope.{FontClass, Weight}

  @enforce_keys ~w(family weight modifiers)a
  defstruct ~w(family foundry foundry_url weight modifiers designer class unique_identifier)a

  @type nonempty_str :: String.t()

  @type unique_identifier() :: %{
    version: String.t(),
    foundry_tag: String.t(),
    family: String.t()
  }

  @type modifier() :: :italic | :variable

  @type t :: %__MODULE__{
    family: nonempty_str(),
    weight: Weight.t(),
    modifiers: [modifier()],
    foundry: nonempty_str() | nil,
    foundry_url: nonempty_str() | nil,
    designer: nonempty_str() | nil,
    class: FontClass.t() | nil,
    unique_identifier: unique_identifier() | nil
  }

  @spec new(map() | keyword()) :: {:ok, FontInfo.t()} | {:error, any()}
  def new(params) do
    params = Map.new(params)

    with {:ok, params} <- validate_family(params),
         {:ok, params} <- validate_weight(params),
         {:ok, params} <- validate_modifiers(params),
         {:ok, params} <- validate_optional_strings(params),
         {:ok, params} <- validate_class(params),
         {:ok, params} <- validate_unique_identifier(params) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  defp validate_family(%{family: family}) when not is_binary(family),
    do: {:error, %{family: "must be a string"}}

  defp validate_family(%{family: family} = params) do
    family = String.trim(family)

    if family == "",
      do: {:error, %{family: "must be nonempty string"}},
      else: {:ok, %{params | family: family}}
  end

  defp validate_weight(%{weight: %Weight{}} = params),
    do: {:ok, params}

  defp validate_weight(%{weight: weight} = params) do
    case Weight.new(weight) do
      {:ok, weight} -> {:ok, %{params | weight: weight}}
      {:error, reason} -> {:error, %{weight: reason}}
    end
  end

  defp validate_modifiers(%{modifiers: modifiers}) when not is_list(modifiers),
    do: {:error, %{modifiers: "must be a list"}}

  defp validate_modifiers(%{modifiers: modifiers} = params) do
    valid_modifiers = [:italic, :variable]

    if Enum.all?(modifiers, &(&1 in valid_modifiers)) do
      {:ok, params}
    else
      {:error, %{modifiers: "must contain only :italic and :variable"}}
    end
  end

  defp validate_optional_strings(params) do
    optional_fields = [:foundry, :foundry_url, :designer]

    Enum.reduce_while(optional_fields, {:ok, params}, fn field, {:ok, acc} ->
      validate_optional_string_field(acc, field)
    end)
  end

  defp validate_optional_string_field(params, field) do
    case Map.get(params, field) do
      nil -> {:cont, {:ok, params}}
      value when not is_binary(value) -> {:halt, {:error, %{field => "must be a string"}}}
      value ->
        trimmed = String.trim(value)
        if trimmed == "" do
          {:halt, {:error, %{field => "must be nonempty string"}}}
        else
          {:cont, {:ok, %{params | field => trimmed}}}
        end
    end
  end

  defp validate_class(%{class: nil} = params), do: {:ok, params}
  defp validate_class(%{class: class} = params) do
    valid_classes = [
      :unclassified, :oldstyle_serif, :transitional_serif, :modern_serif,
      :clarendon_serif, :slab_serif, :freeform_serif, :sans_serif,
      :ornamental, :script, :symbolic
    ]

    if class in valid_classes do
      {:ok, params}
    else
      {:error, %{class: "must be a valid FontClass"}}
    end
  end

  defp validate_unique_identifier(%{unique_identifier: nil} = params), do: {:ok, params}
  defp validate_unique_identifier(%{unique_identifier: ui}) when not is_map(ui),
    do: {:error, %{unique_identifier: "must be a map"}}

  defp validate_unique_identifier(%{unique_identifier: ui} = params) do
    required_keys = [:version, :foundry_tag, :family]

    if Enum.all?(required_keys, &Map.has_key?(ui, &1)) and
       Enum.all?(required_keys, fn key -> is_binary(Map.get(ui, key)) end) do
      {:ok, params}
    else
      {:error, %{unique_identifier: "must have version, foundry_tag, and family as strings"}}
    end
  end
end
