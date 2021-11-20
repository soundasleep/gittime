class ConfigFile
  attr_reader :sources, :authors, :default_source

  def initialize(yaml)
    fail "No sources defined" unless yaml["sources"]

    @default_source = DefaultSource.new(yaml["default_source"])
    @sources = yaml["sources"].map { |row| Source.new(row, @default_source) }
    @authors = yaml["authors"]
  end

  def select_author(label)
    authors.each do |author, matches|
      matches.each do |match|
        if label.match?(match)
          return author
        end
      end
    end
    label
  end
end
