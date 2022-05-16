class Array
  class ArrayOnlyError < StandardError; end

  def only
    if size != 1
      raise ArrayOnlyError.new("expected only a single element, got #{size} in #{self}")
    end
    first
  end
end
