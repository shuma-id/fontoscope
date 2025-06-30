defmodule Fontoscope.FontInfo do
  @moduledoc false
  use Domo

  @enforce_keys [:family, :weight, :is_italic]
  defstruct [:family, :foundry, :foundry_url, :weight, :is_italic]

  @type weight :: non_neg_integer()
  precond(weight: &(&1 >= 100 and &1 <= 900))

  @type nonempty_str :: String.t()
  precond(nonempty_str: &(String.length(String.trim(&1)) > 0))

  @type t :: %__MODULE__{
    family: nonempty_str(),
    weight: weight(),
    is_italic: boolean(),
    foundry: nonempty_str() | nil,
    foundry_url: nonempty_str() | nil
  }

end
