require "yaml"

class InitConfigFile
  attr_reader :file

  def initialize(file:)
    @file = file
  end

  def call
    File.write(file, default_config_file)
    LOG.info "Wrote default config file to #{file}"
  end

  private

  def default_config_file
    File.read("config.init.yml")
  end
end
