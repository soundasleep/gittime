class ConfigFile
  attr_reader :sources, :authors, :default_source, :categories, :only_filters
  attr_reader :path
  attr_reader :options

  class NoAuthorsDefinedError < StandardError; end

  def initialize(yaml, path, options)
    fail "No sources defined" unless yaml["sources"]

    @path = path
    @options = options

    @default_source = DefaultSource.new(yaml["default_source"] || default_source_params)
    @sources = yaml["sources"].map do |row|
      if row.is_a?(Array) # named source
        named_source_name = row[0]
        row = row[1]
      end
      Source.new(row, self, @default_source, options)
    end
    @authors = yaml["authors"] or raise NoAuthorsDefinedError.new("no authors defined in config: '#{yaml}'")
    @categories = yaml["categories"] || {}
    @only_filters = yaml["only"] || {}
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
