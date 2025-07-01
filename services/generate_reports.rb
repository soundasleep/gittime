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
    reports << write_report!("revisions.csv", REVISIONS_HEADERS + config_category_headers, revisions)
    reports << write_report!("revisions-with-authors.csv", REVISIONS_HEADERS + config_category_headers, revisions_with_authors)
    reports << write_report!("blocks.csv", BLOCKS_HEADERS + config_category_headers, blocks)
    reports << write_report!("blocks-by-month.csv", BLOCKS_BY_MONTHS_HEADERS + config_category_headers, blocks_by_month)
    reports << write_report!("work-by-month.csv", WORK_BY_MONTHS_HEADERS + config_category_headers, work_by_month)
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

  def config_category_headers
    config.categories.map { |key, _| "#{key} %" } + ["#{OTHER_CATEGORY} %"]
  end

  OTHER_CATEGORY = "other"

  REVISIONS_HEADERS = ["ID", "Author", "Date", "Source", "Message"]

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
        .map do |revision|
          revision.merge(populate_revision_categories(revision))
        end
  end

  def config_category_headers_empty_map
    result = {}
    config_category_headers.each do |label|
      result[label] = 0
    end
    result
  end

  def select_category_values_as_map(row)
    result = {}
    config_category_headers.each do |label|
      result[label] = row[label]
    end
    result
  end

  def populate_revision_categories(revision)
    result = config_category_headers_empty_map

    if revision[:paths] && !revision[:paths].empty?
      # we weight revisions based on the % of paths that match each category
      if !revision[:paths].is_a?(Array)
        revision[:paths] = [revision[:paths]]
      end

      one_path_percent = 1.0 / revision[:paths].size
      revision[:paths].each do |path|
        category = select_category_for(path)
        result["#{category} %"] += one_path_percent
      end
    else
      # we mark every category, other than 'other %', as 0.
      result["#{OTHER_CATEGORY} %"] = 1.0
    end

    result
  end

  def select_category_for(path)
    config.categories.each do |key, values|
      values.each do |regexp|
        return key if path.match?(regexp)
      end
    end

    return OTHER_CATEGORY
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

  def print_revision_row(row)
    [
      row[:id],
      row[:author_label] || row[:author],
      print_date(row[:author_date]),
      row[:source].label,
      row[:message]
    ] + select_category_values_as_array(row)
  end

  def select_category_values_as_array(row)
    config_category_headers.map { |label| row[label] }
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
        add_categorised_revisions_to_block!(current_author_blocks[key], row)
      end

      # Finally if there are any pending blocks, add them in
      current_author_blocks.each do |_, block|
        result << block
      end

      result
    end.sort { |a, b| [a[:author_label], a[:start]] <=> [b[:author_label], b[:start]] }
  end

  def add_categorised_revisions_to_block!(current_block, row)
    if current_block[:count] > 1
      # Un-weight existing values based on how many commits there were _before_ this block
      config_category_headers.each do |key|
        current_block[key] *= (current_block[:count] - 1)
      end
    end
    config_category_headers.each do |key|
      current_block[key] += row[key]
      # And now re-weight, giving each commit equal weighting
      current_block[key] /= current_block[:count]
    end
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
    ] + select_category_values_as_array(row)
  end

  def in_local_tz(date)
    date.in_time_zone(options[:time_zone])
  end

  def blocks_by_month_data
    @blocks_by_month_data ||= begin
      id = 0
      result = []
      blocks_data.each do |block|
        category_data = select_category_values_as_map(block)

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
          }.merge(category_data)
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
        }.merge(category_data)
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
    }.merge(config_category_headers_empty_map)
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
    [ row[:id], print_date(row[:start]), print_date(row[:end]), row[:author_label], row[:start_id], row[:end_id], row[:start_source].label, row[:end_source].label, row[:count] ] + select_category_values_as_array(row)
  end

  WORK_BY_MONTHS_HEADERS = ["ID", "Month starting", "Author", "Seconds", "Blocks", "Start date", "End date"]

  # Number of seconds of "work" done by each author per month
  def work_by_month
    @work_by_month ||= work_by_month_data.map { |row| print_work_by_month_row(row) }
  end

  def print_work_by_month_row(row)
    [ row[:id], print_date(row[:start].beginning_of_month), row[:author_label], row[:seconds], row[:blocks], print_date(row[:start]), print_date(row[:end]) ] + select_category_values_as_array(row)
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
        add_categorised_revisions_to_work_block!(current_work_blocks[key], block)
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
    }.merge(config_category_headers_empty_map)
  end

  def add_categorised_revisions_to_work_block!(current_block, row)
    if current_block[:blocks] > 1
      # Un-weight existing values based on how many commits there were _before_ this block
      config_category_headers.each do |key|
        current_block[key] *= (current_block[:blocks] - 1)
      end
    end
    config_category_headers.each do |key|
      current_block[key] += row[key]
      # And now re-weight, giving each commit equal weighting
      current_block[key] /= current_block[:blocks]
    end
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
