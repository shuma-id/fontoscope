# According to IBM Font Family Classification
# https://learn.microsoft.com/en-us/typography/opentype/spec/ibmfc
defmodule Fontoscope.FontClass do
  @type t() :: :unclassified | :oldstyle_serif | :transitional_serif | :modern_serif
             | :clarendon_serif | :slab_serif | :freeform_serif | :sans_serif
             | :ornamental | :script | :symbolic
end
