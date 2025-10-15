defmodule Fontoscope.FontInfo do
  @moduledoc false
  use Domo

  alias Fontoscope.{FontClass, Weight}

  @enforce_keys [:family, :weight, :modifiers]
  defstruct [:family, :foundry, :foundry_url, :weight, :modifiers, :designer, :class, :unique_identifier]

  @type nonempty_str :: String.t()
  precond(nonempty_str: &(String.length(String.trim(&1)) > 0))

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

end
