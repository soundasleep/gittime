require "yaml"
require "csv"

class GenerateReports
  attr_reader :config, :options

  def initialize(config:, options:)
    @config = config
    @options = options
  end

  REVISIONS_HEADERS = ["ID", "Author", "Date", "Source", "Message"]

  def call
    FileUtils.mkdir_p(options[:output])

    File.write report_path("revisions.csv"), to_csv([REVISIONS_HEADERS] + revisions)
    LOG.info "Wrote #{report_path("revisions.csv")}"
  end

  private

  def report_path(file)
    "#{options[:output]}#{file}"
  end

  def revisions
    config.sources.map(&:revisions).map do |revisions|
      revisions.map do |revision|
        [ revision[:id], revision[:author], revision[:author_date], revision[:source], revision[:message] ]
      end
    end.flatten(1).sort { |a, b| [a[2], a[3]] <=> [b[2], b[3]] }
  end

  def to_csv(arrays)
    arrays.map(&:to_csv).join
  end
end
