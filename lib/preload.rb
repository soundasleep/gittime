$LOAD_PATH << ENV['GEM_HOME'] if ENV['GEM_HOME']

require "active_support"
require "active_support/core_ext"

require_relative "monkey_patches"
require_relative "options"
require_relative "logging"
require_relative "deep_merge"

# alternative to ActiveSupport::Dependencies.autoload_paths,
# which no longer seems to work?
load_everything_in = [
  File.join(File.dirname(__FILE__), '..', 'lib'),
  File.join(File.dirname(__FILE__), '..', 'helpers'),
  File.join(File.dirname(__FILE__), '..', 'model'),
  File.join(File.dirname(__FILE__), '..', 'services'),
]

load_everything_in.each do |path|
  Dir[File.join(path, "*.rb")].each do |file|
    require file
  end
end
