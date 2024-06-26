require "yaml"

class ReadConfigFile
  attr_reader :file, :options

  def initialize(file:, options:)
    @file = file
    @options = options
  end

  def call
    yaml = load_yaml(file)
    yaml["merge"] ||= {}

    yaml["merge"].each do |filename|
      resolved_filename = File.expand_path('../' + filename, file)
      yaml = deep_merge(yaml, load_yaml(resolved_filename))
    end

    ConfigFile.new(yaml, File.expand_path(file), options)
  end

  private

  def load_yaml(filename)
    yaml_source = File.read(file)
    yaml_source = replace_environment_variables(yaml_source)

    YAML.load(yaml_source)
  end

  def replace_environment_variables(yaml_source)
    return yaml_source unless options[:env]

    env = YAML.load_file(options[:env])
    env.each do |key, value|
      yaml_source = yaml_source.gsub("${{ #{key} }}", value)
    end

    yaml_source
  end
end
