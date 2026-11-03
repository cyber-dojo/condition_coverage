def long?(name)
  name.size > 2 && name.ascii_only?
end
