# active_support's deep merge only handles a single depth
require 'deep_merge/rails_compat'

def deep_merge(target, source)
  if target.is_a?(Array) && source.is_a?(Array)
    return target + source
  end

  return target.deeper_merge(source)
end
