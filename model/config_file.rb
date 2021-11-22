class ConfigFile
  attr_reader :sources, :authors, :default_source
  attr_reader :path

  def initialize(yaml, path)
    fail "No sources defined" unless yaml["sources"]

    @path = path

    @default_source = DefaultSource.new(yaml["default_source"])
    @sources = yaml["sources"].map { |row| Source.new(row, self, @default_source) }
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
