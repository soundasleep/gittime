def deep_merge(target, source)
  result = {}
  target.each do |k, v|
    result[k] = v
  end

  source.each do |k, v|
    if result[k].is_a?(Array)
      v.each do |vv|
        result[k] << vv
      end
    elsif result[k].respond_to?(:[])
      v.each do |kk, vv|
        result[k][kk] ||= vv
      end
    else
      result[k] ||= v
    end
  end

  result
end
