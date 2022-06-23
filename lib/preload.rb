$LOAD_PATH << ENV['GEM_HOME'] if ENV['GEM_HOME']

require "active_support"

ActiveSupport::Dependencies.autoload_paths = [
  File.join(File.dirname(__FILE__), '..', 'lib'),
  File.join(File.dirname(__FILE__), '..', 'helpers'),
  File.join(File.dirname(__FILE__), '..', 'model'),
  File.join(File.dirname(__FILE__), '..', 'services'),
]

require_relative "monkey_patches"
require_relative "options"
require_relative "logging"
require_relative "deep_merge"
