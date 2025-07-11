defmodule Fontoscope.FontInfo do
  @moduledoc false
  use Domo

  alias Fontoscope.{Weight, FontClass}

  @enforce_keys [:family, :weight, :is_italic]
  defstruct [:family, :foundry, :foundry_url, :weight, :is_italic, :designer, :class]

  @type nonempty_str :: String.t()
  precond(nonempty_str: &(String.length(String.trim(&1)) > 0))

  @type t :: %__MODULE__{
    family: nonempty_str(),
    weight: Weight.t(),
    is_italic: boolean(),
    foundry: nonempty_str() | nil,
    foundry_url: nonempty_str() | nil,
    designer: nonempty_str() | nil,
    class: FontClass.t() | nil
  }

end
