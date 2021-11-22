require "yaml"

class ReadConfigFile
  attr_reader :file

  def initialize(file:)
    @file = file
  end

  def call
    ConfigFile.new(YAML.load_file(file), File.expand_path(file))
  end
end
