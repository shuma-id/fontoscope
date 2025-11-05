defmodule Fontoscope.Weight do
  @moduledoc false

  @enforce_keys ~w(label value)a
  defstruct ~w(label value)a

  @type t :: %__MODULE__{
          label: String.t(),
          value: non_neg_integer()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, any()}
  def new(params) do
    params = Map.new(params)

    with {:ok, params} <- validate_label(params),
         {:ok, params} <- validate_value(params) do
      {:ok, struct(__MODULE__, params)}
    end
  end

  defp validate_label(%{label: label}) when not is_binary(label),
    do: {:error, %{label: "must be a string"}}

  defp validate_label(%{label: label} = params) do
    label = String.trim(label)

    if label == "",
      do: {:error, %{label: "must be nonempty string"}},
      else: {:ok, %{params | label: label}}
  end

  defp validate_value(%{value: value}) when not is_integer(value),
    do: {:error, %{value: "must be an integer"}}

  defp validate_value(%{value: value}) when value < 100 or value > 950,
    do: {:error, %{value: "must be between 100 and 950"}}

  defp validate_value(params), do: {:ok, params}
end
