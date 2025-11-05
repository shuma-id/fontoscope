defmodule Fontoscope.FontInfo do
  @moduledoc false

  require Fontoscope.FontClass
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
    params =
      Map.merge(
        %{
          foundry: nil,
          foundry_url: nil,
          designer: nil,
          class: nil,
          unique_identifier: nil
        },
        Map.new(params)
      )

    with {:ok, params} <- validate_family(params),
         {:ok, params} <- validate_weight(params),
         {:ok, params} <- validate_modifiers(params),
         {:ok, params} <- validate_foundry_designer(params),
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
    valid_modifiers = ~w(italic variable)a

    if Enum.all?(modifiers, &(&1 in valid_modifiers)) do
      {:ok, params}
    else
      {:error, %{modifiers: "must contain only :italic and :variable"}}
    end
  end

  defp validate_foundry_designer(params) do
    optional_fields = ~w(foundry foundry_url designer)a

    optional_fields
    |> Enum.map(&{&1, Map.get(params, &1)})
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      {key, ensure_nonempty_string(value)}
    end)
    |> Enum.reduce({:ok, params}, fn
      {key, {:ok, value}}, {:ok, params} -> {:ok, %{params | key => value}}
      {key, {:error, reason}}, _acc -> {:error, %{key => reason}}
      _value, {:error, reason} -> {:error, reason}
    end)
  end

  defp ensure_nonempty_string(value) when not is_binary(value),
    do: {:error, "must be a string"}

  defp ensure_nonempty_string(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, "must be nonempty string"}
    else
      {:ok, trimmed}
    end
  end

  defp validate_class(%{class: nil} = params), do: {:ok, params}

  defp validate_class(%{class: class} = params) do
    valid_classes = FontClass.values()

    if class in valid_classes do
      {:ok, params}
    else
      {:error, %{class: "must be a valid FontClass, given: #{inspect(class)}"}}
    end
  end

  defp validate_unique_identifier(%{unique_identifier: nil} = params), do: {:ok, params}

  defp validate_unique_identifier(%{unique_identifier: ui}) when not is_map(ui),
    do: {:error, %{unique_identifier: "must be a map"}}

  defp validate_unique_identifier(%{unique_identifier: ui} = params) do
    required_keys = ~w(version foundry_tag family)a

    if Enum.all?(required_keys, fn key -> is_binary(Map.get(ui, key)) end) do
      {:ok, params}
    else
      {:error, %{unique_identifier: "must have version, foundry_tag, and family as strings"}}
    end
  end
end
