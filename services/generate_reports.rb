require "yaml"
require "csv"
require "active_support/time"

class GenerateReports
  attr_reader :config, :options

  def initialize(config:, options:)
    @config = config
    @options = options
  end

  def call
    FileUtils.mkdir_p(options[:output])

    write_report! "revisions.csv", REVISIONS_HEADERS, revisions
    write_report! "revisions-with-authors.csv", REVISIONS_HEADERS, revisions_with_authors
    write_report! "blocks.csv", BLOCKS_HEADERS, blocks
  end

  private

  def write_report!(filename, headers, data)
    File.write report_path(filename), to_csv([headers] + data)
    LOG.info "Wrote #{report_path(filename)}"
  end

  def report_path(file)
    "#{options[:output]}#{file}"
  end

  REVISIONS_HEADERS = ["ID", "Author", "Date", "Source", "Message"]

  # A list of points of times
  def revisions
    @revisions ||= revisions_data.map do |row|
      [ row[:id], row[:author], row[:author_date], row[:source].label, row[:message] ]
    end
  end

  def revisions_data
    @revisions_data ||= config.sources.map(&:revisions)
        .flatten(1)
        .sort { |a, b| [a[:author_date], a[:source].label] <=> [b[:author_date], b[:source].label] }
  end

  # A list of revisions with mapped authors, and duplicate rows removed
  def revisions_with_authors
    @revisions_with_authors ||= revisions_with_authors_data.map do |row|
      [ row[:id], row[:author_label], row[:author_date], row[:source].label, row[:message] ]
    end
  end

  def revisions_with_authors_data
    @revisions_with_authors_data ||= revisions_data.map do |row|
      row[:author_label] = config.select_author(row[:author])
      row
    end.uniq { |row| [row[:author_label], row[:author_date].to_time.to_i] }
  end

  BLOCKS_HEADERS = ["Start date", "End date", "Author", "Start ID", "End ID", "Start Source", "End Source", "Revisions"]

  # A list of continuous blocks, by author
  def blocks
    @blocks ||= blocks_data.map do |row|
      [ row[:start], row[:end], row[:author_label], row[:start_id], row[:end_id], row[:start_source].label, row[:end_source].label, row[:count] ]
    end
  end

  def blocks_data
    @blocks_data ||= begin
      result = []
      current_author_blocks = {} # hash of author_label => data
      revisions_with_authors_data.each do |row|
        key = row[:author_label]

        if current_author_blocks[key].nil?
          current_author_blocks[key] = new_current_author_block(row)
        else
          if row[:author_date] - row[:source].before.seconds < current_author_blocks[key][:end]
            # Extend the existing block
            current_author_blocks[key][:end] = row[:author_date] + row[:source].after.seconds
            current_author_blocks[key][:end_id] = row[:id]
            current_author_blocks[key][:end_source] = row[:source]
            current_author_blocks[key][:count] += 1
          else
            # The previous block has run out, store it and create another
            result << current_author_blocks[key]
            current_author_blocks[key] = new_current_author_block(row)
          end
        end
      end

      # Finally if there are any pending blocks, add them in
      current_author_blocks.each do |_, block|
        result << block
      end

      result
    end.sort { |a, b| [a[:author_label], a[:start]] <=> [b[:author_label], b[:start]] }
  end

  def new_current_author_block(row)
    {
      start: row[:author_date] - row[:source].before.seconds,
      end: row[:author_date] + row[:source].after.seconds,
      author_label: row[:author_label],
      start_id: row[:id],
      end_id: row[:id],
      start_source: row[:source],
      end_source: row[:source],
      count: 1,
    }
  end

  def unique_author_labels
    @unique_author_labels ||= revisions_with_authors_data.map { |row| row[:author_label] }.compact.uniq
  end

  def to_csv(arrays)
    arrays.map(&:to_csv).join
  end
end
