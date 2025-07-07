defmodule Fontoscope.Weight do
  @moduledoc false
  use Domo

  @enforce_keys [:label, :value]
  defstruct [:label, :value]

  @type value() :: non_neg_integer()
  precond(value: &(&1 >= 100 && &1 <= 950))

  @type t :: %__MODULE__{
    label: String.t(),
    value: non_neg_integer()
  }

end
