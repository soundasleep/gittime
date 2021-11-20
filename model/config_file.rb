class ConfigFile
  attr_reader :sources, :authors

  def initialize(yaml)
    fail "No sources defined" unless yaml["sources"]

    @sources = yaml["sources"].map { |row| Source.new(row) }
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
