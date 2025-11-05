defmodule Fontoscope.FontClass do
  @moduledoc """
  Font classes accroding to [IBM Font Family Classification](https://learn.microsoft.com/en-us/typography/opentype/spec/ibmfc)
  """

  @type t() ::
          :unclassified
          | :oldstyle_serif
          | :transitional_serif
          | :modern_serif
          | :clarendon_serif
          | :slab_serif
          | :freeform_serif
          | :sans_serif
          | :ornamental
          | :script
          | :symbolic

  @spec values() :: [t, ...]
  def values do
    ~w(unclassified oldstyle_serif transitional_serif modern_serif
      clarendon_serif slab_serif freeform_serif sans_serif
      ornamental script symbolic)a
  end
end
