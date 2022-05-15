class Array
  def only
    if size != 1
      raise "expected only a single element, got #{size} in #{self}"
    end
    first
  end
end
