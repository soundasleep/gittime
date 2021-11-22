require "yaml"
require "csv"
require "active_support/time"

class GenerateReports
  include DateHelper

  attr_reader :config, :options

  def initialize(config:, options:)
    @config = config
    @options = options
  end

  def call
    FileUtils.mkdir_p(options[:output])

    reports = []
    reports << write_report!("revisions.csv", REVISIONS_HEADERS, revisions)
    reports << write_report!("revisions-with-authors.csv", REVISIONS_HEADERS, revisions_with_authors)
    reports << write_report!("blocks.csv", BLOCKS_HEADERS, blocks)
    reports << write_report!("blocks-by-month.csv", BLOCKS_BY_MONTHS_HEADERS, blocks_by_month)
    reports << write_report!("work-by-month.csv", WORK_BY_MONTHS_HEADERS, work_by_month)
    reports
  end

  private

  def write_report!(filename, headers, data)
    File.write report_path(filename), to_csv([headers] + data)
    LOG.info "Wrote #{report_path(filename)}"

    {
      filename: filename,
      headers: headers,
      data: data,
    }
  end

  def report_path(file)
    "#{options[:output]}#{file}"
  end

  REVISIONS_HEADERS = ["ID", "Author", "Date", "Source", "Message"]

  # A list of points of times
  def revisions
    @revisions ||= revisions_data.map { |row| print_revision_row(row) }
  end

  def revisions_data
    @revisions_data ||= config.sources.map(&:revisions)
        .flatten(1)
        .sort { |a, b| [a[:author_date], a[:source].label] <=> [b[:author_date], b[:source].label] }
  end

  # A list of revisions with mapped authors, and duplicate rows removed
  def revisions_with_authors
    @revisions_with_authors ||= revisions_with_authors_data.map { |row| print_revision_row(row) }
  end

  def revisions_with_authors_data
    @revisions_with_authors_data ||= revisions_data.map do |row|
      row[:author_label] = config.select_author(row[:author])
      row
    end.uniq { |row| [row[:author_label], row[:author_date].to_time.to_i] }
  end

  def print_revision_row(row)
    [ row[:id], row[:author_label] || row[:author], print_date(row[:author_date]), row[:source].label, row[:message] ]
  end

  BLOCKS_HEADERS = ["Start date", "End date", "Author", "Start ID", "End ID", "Start Source", "End Source", "Revisions"]

  # A list of continuous blocks, by author
  def blocks
    @blocks ||= blocks_data.map { |row| print_block_row(row) }
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

  BLOCKS_BY_MONTHS_HEADERS = ["Start date", "End date", "Author", "Month", "Year"]

  # Split multi-month blocks into individual blocks
  def blocks_by_month
    @blocks_by_month ||= blocks_by_month_data.map do |row|
      [ print_date(row[:start]), print_date(row[:end]), row[:author_label], row[:month], row[:year] ]
    end
  end

  def blocks_by_month_data
    @blocks_by_month_data ||= begin
      result = []
      blocks_data.each do |block|
        while print_month(block[:start]) != print_month(block[:end])
          result << {
            start: block[:start],
            end: block[:start].end_of_month,
            author_label: block[:author_label],
            month: block[:start].strftime("%-m"),
            year: block[:start].strftime("%Y"),
          }
          block[:start] = (block[:start] + 1.month).beginning_of_month
        end
        result << {
          start: block[:start],
          end: block[:end],
          author_label: block[:author_label],
          month: block[:start].strftime("%-m"),
          year: block[:start].strftime("%Y"),
        }
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

  def print_month(date)
    date.strftime("%m-%y")
  end

  def print_block_row(row)
    [ print_date(row[:start]), print_date(row[:end]), row[:author_label], row[:start_id], row[:end_id], row[:start_source].label, row[:end_source].label, row[:count] ]
  end

  WORK_BY_MONTHS_HEADERS = ["Month starting", "Author", "Seconds", "Blocks", "Start date", "End date"]

  # Number of seconds of "work" done by each author per month
  def work_by_month
    @work_by_month ||= work_by_month_data.map do |row|
      [ print_date(row[:start].beginning_of_month), row[:author_label], row[:seconds], row[:blocks], print_date(row[:start]), print_date(row[:end]) ]
    end
  end

  def work_by_month_data
    @work_by_month_data ||= begin
      result = []
      current_work_blocks = {}

      blocks_by_month_data.each do |block|
        key = block[:author_label]

        if current_work_blocks[key].nil?
          current_work_blocks[key] = new_current_work_block(block)
        else
          if block[:start].beginning_of_month == current_work_blocks[key][:start].beginning_of_month
            current_work_blocks[key][:end] = block[:end]
            current_work_blocks[key][:seconds] += block_seconds(block)
            current_work_blocks[key][:blocks] += 1
          else
            result << current_work_blocks[key]
            current_work_blocks[key] = new_current_work_block(block)
          end
        end
      end

      current_work_blocks.each do |_, row|
        result << row
      end

      result
    end
  end

  def new_current_work_block(block)
    {
      start: block[:start],
      end: block[:end],
      author_label: block[:author_label],
      seconds: block_seconds(block),
      blocks: 1,
    }
  end

  def block_seconds(block)
    block[:end].to_time.to_i - block[:start].to_time.to_i
  end

  def unique_author_labels
    @unique_author_labels ||= revisions_with_authors_data.map { |row| row[:author_label] }.compact.uniq
  end

  def to_csv(arrays)
    arrays.map(&:to_csv).join
  end
end
