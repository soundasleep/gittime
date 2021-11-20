class ConfigFile
  attr_reader :sources

  def initialize(yaml)
    fail "No sources defined" unless yaml["sources"]

    @sources = yaml["sources"].map { |row| Source.new(row) }
  end
end
