class ConfigFile
  attr_reader :sources, :authors, :default_source, :categories
  attr_reader :path

  class NoAuthorsDefinedError < StandardError; end

  def initialize(yaml, path)
    fail "No sources defined" unless yaml["sources"]

    @path = path

    @default_source = DefaultSource.new(yaml["default_source"] || default_source_params)
    @sources = yaml["sources"].map { |row| Source.new(row, self, @default_source) }
    @authors = yaml["authors"] or raise NoAuthorsDefinedError.new("no authors defined in config: '#{yaml}'")
    @categories = yaml["categories"] || {}
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

  private

  def default_source_params
    {
      "before": "1 hour",
      "after": "1 hour",
    }
  end
end
