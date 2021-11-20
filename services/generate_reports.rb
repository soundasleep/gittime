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

    write_report! "revisions.csv", REVISIONS_HEADERS, revisions
    write_report! "revisions-with-authors.csv", REVISIONS_HEADERS, revisions_with_authors
  end

  private

  def write_report!(filename, headers, data)
    File.write report_path(filename), to_csv([headers] + data)
    LOG.info "Wrote #{report_path(filename)}"
  end

  def report_path(file)
    "#{options[:output]}#{file}"
  end

  def revisions
    @revisions ||= config.sources.map(&:revisions).map do |revisions|
      revisions.map do |revision|
        [ revision[:id], revision[:author], revision[:author_date], revision[:source].label, revision[:message] ]
      end
    end.flatten(1).sort { |a, b| [a[2], a[3]] <=> [b[2], b[3]] }
  end

  def revisions_with_authors
    @revisions_with_authors ||= revisions.map do |row|
      [ row[0], config.select_author(row[1]), row[2], row[3], row[4] ]
    end.uniq { |row| [row[1], row[2].to_time.to_i] }
  end

  def to_csv(arrays)
    arrays.map(&:to_csv).join
  end
end
