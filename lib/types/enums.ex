import EnumType

# According to IBM Font Family Classification
# https://learn.microsoft.com/en-us/typography/opentype/spec/ibmfc
defenum Fontoscope.FontClass do
  value Unclassified, "Unclassified"
  value OldstyleSerif, "Oldstyle Serif"
  value TransitionalSerif, "Transitional Serif"
  value ModernSerif, "Modern Serif"
  value ClarendonSerif, "Clarendon Serif"
  value SlabSerif, "Slab Serif"
  value FreeformSerif, "Freeform Serif"
  value SansSerif, "Sans Serif"
  value Ornamental, "Ornamental"
  value Script, "Script"
  value Symbolic, "Symbolic"
end
