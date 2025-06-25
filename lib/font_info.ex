defmodule Fontoscope.FontInfo do
  @moduledoc false

  defstruct [:family, :foundry, :foundry_url, :weight]

  @enforce_keys [:family, :weight]

  @type t :: %__MODULE__{
    family: String.t(),
    weight: non_neg_integer(),
    foundry: String.t() | nil,
    foundry_url: String.t() | nil
  }

  @doc """
  Create a new font info
  """
  @spec new(map()) :: t()
  def new(params) do
    struct!(__MODULE__, params)
  end

end
