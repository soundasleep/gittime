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
    FileUtils.mkdir_p(report_path("."))

    reports = []
    reports << write_report!("revisions.csv", REVISIONS_HEADERS, revisions)
    reports << write_report!("revisions-with-authors.csv", REVISIONS_HEADERS, revisions_with_authors)
    reports << write_report!("blocks.csv", BLOCKS_HEADERS, blocks)
    reports << write_report!("blocks-by-month.csv", BLOCKS_BY_MONTHS_HEADERS, blocks_by_month)
    reports << write_report!("work-by-month.csv", WORK_BY_MONTHS_HEADERS, work_by_month)
    reports << write_report!("authors.csv", AUTHORS_HEADERS, authors)
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
    File.join(File.dirname(config.path), options[:output], file)
  end

  REVISIONS_HEADERS = ["ID", "Author", "Date", "Source", "Message"]
  AUTHORS_HEADERS = ["Author", "Original Author"]

  # A list of points of times
  def revisions
    @revisions ||= revisions_data.map { |row| print_revision_row(row) }
  end

  def revisions_data
    @revisions_data ||= config.sources.map(&:revisions)
        .flatten(1)
        .map do |revision|
          revision[:author_date] = revision[:author_date].in_time_zone(options[:time_zone])
          revision
        end
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
    end.select do |revision|
        config.only_filters.empty? || config.only_filters["authors"].empty? || config.only_filters["authors"].include?(revision[:author_label])
      end
      .uniq { |row| [row[:author_label], row[:author_date].to_time.to_i] }
  end

  # a list of all authors we found and their source author ID before selecting from config,
  # and including all authors ignored by any 'only' filter
  def authors
    @authors ||= authors_data.map { |row| print_author_row(row) }
  end

  def authors_data
    @authors_data ||= revisions_data.map do |row|
      {
        :author => config.select_author(row[:author]),
        :original_author => row[:author]
      }
    end.uniq
      .sort { |a, b| [ a[:author], a[:original_author] ] <=> [ b[:author], b[:original_author] ] }
  end

  def print_revision_row(row)
    [
      row[:id],
      row[:author_label] || row[:author],
      print_date(row[:author_date]),
      row[:source].label,
      row[:message]
    ]
  end

  def print_author_row(row)
    [
      row[:author],
      row[:original_author]
    ]
  end

  BLOCKS_HEADERS = ["ID", "Start date", "End date", "Author", "Start ID", "End ID", "Start Source", "End Source", "Revisions"]

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
            current_author_blocks[key][:end] = author_block_row_event_end_time(row)
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

  BLOCKS_BY_MONTHS_HEADERS = ["ID", "Start date", "End date", "Author", "Month", "Year", "Source block ID"]

  # Split multi-month blocks into individual blocks
  def blocks_by_month
    @blocks_by_month ||= blocks_by_month_data.map { |row| print_block_by_month_row(row) }
  end

  def print_block_by_month_row(row)
    [
      row[:id],
      print_date(row[:start]),
      print_date(row[:end]),
      row[:author_label],
      row[:month],
      row[:year],
      row[:source]
    ]
  end

  def in_local_tz(date)
    date.in_time_zone(options[:time_zone])
  end

  def blocks_by_month_data
    @blocks_by_month_data ||= begin
      id = 0
      result = []
      blocks_data.each do |block|
        while print_month(block[:start]) != print_month(block[:end])
          id += 1
          result << {
            id: id,
            start: block[:start],
            end: block[:start].end_of_month,
            author_label: block[:author_label],
            month: in_local_tz(block[:start]).strftime("%-m"),
            year: in_local_tz(block[:start]).strftime("%Y"),
            source: block[:id],
          }
          block[:start] = (block[:start].end_of_month + 1.day).beginning_of_month
        end
        id += 1
        result << {
          id: id,
          start: block[:start],
          end: block[:end],
          author_label: block[:author_label],
          month: in_local_tz(block[:start]).strftime("%-m"),
          year: in_local_tz(block[:start]).strftime("%Y"),
          source: block[:id],
        }
      end
      result
    end.sort { |a, b| [a[:author_label], a[:start]] <=> [b[:author_label], b[:start]] }
  end

  def new_current_author_block(row)
    @new_current_author_block_id ||= 0
    @new_current_author_block_id += 1

    {
      id: @new_current_author_block_id,
      start: row[:author_date] - row[:source].before.seconds,
      end: author_block_row_event_end_time(row),
      author_label: row[:author_label],
      start_id: row[:id],
      end_id: row[:id],
      start_source: row[:source],
      end_source: row[:source],
      count: 1,
    }
  end

  def author_block_row_event_end_time(row)
    if row[:event_length]
      row[:author_date] + row[:event_length].seconds + row[:source].after.seconds
    else
      row[:author_date] + row[:source].after.seconds
    end
  end

  def print_month(date)
    in_local_tz(date).strftime("%m-%y")
  end

  def print_block_row(row)
    [ row[:id], print_date(row[:start]), print_date(row[:end]), row[:author_label], row[:start_id], row[:end_id], row[:start_source].label, row[:end_source].label, row[:count] ]
  end

  WORK_BY_MONTHS_HEADERS = ["ID", "Month starting", "Author", "Seconds", "Blocks", "Start date", "End date"]

  # Number of seconds of "work" done by each author per month
  def work_by_month
    @work_by_month ||= work_by_month_data.map { |row| print_work_by_month_row(row) }
  end

  def print_work_by_month_row(row)
    [ row[:id], print_date(row[:start].beginning_of_month), row[:author_label], row[:seconds], row[:blocks], print_date(row[:start]), print_date(row[:end]) ]
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
    end.sort { |a, b| [a[:author_label], a[:start]] <=> [b[:author_label], b[:start]] }
  end

  def new_current_work_block(block)
    @new_current_work_block ||= 0
    @new_current_work_block += 1

    {
      id: @new_current_work_block,
      start: block[:start],
      end: block[:end],
      author_label: block[:author_label],
      seconds: block_seconds(block),
      blocks: 1,
    }
  end

  def block_seconds(block)
    if block[:end] < block[:start]
      fail "Block #{block} starts after it ends"
    end

    block[:end].to_time.to_i - block[:start].to_time.to_i
  end

  def unique_author_labels
    @unique_author_labels ||= revisions_with_authors_data.map { |row| row[:author_label] }.compact.uniq
  end

  def to_csv(arrays)
    arrays.map(&:to_csv).join
  end
end
