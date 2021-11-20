$LOAD_PATH << ENV['GEM_HOME'] if ENV['GEM_HOME']

require "active_support"

ActiveSupport::Dependencies.autoload_paths = [
  "lib/",
  "helpers/",
  "model/",
  "services/",
]

require_relative "options"
require_relative "logging"
