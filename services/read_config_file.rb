require "yaml"

class ReadConfigFile
  attr_reader :file, :options

  def initialize(file:, options:)
    @file = file
    @options = options
  end

  def call
    yaml = YAML.load_file(file)
    yaml["merge"] ||= {}

    yaml["merge"].each do |filename|
      resolved_filename = File.expand_path('../' + filename, file)
      yaml = deep_merge(yaml, YAML.load_file(resolved_filename))
    end

    ConfigFile.new(yaml, File.expand_path(file), options)
  end
end
