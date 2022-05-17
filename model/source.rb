require "csv"

class Source
  include CommandLineHelper
  include SecondsHelper

  attr_reader :config_file

  attr_reader :git, :svn, :xls, :csv
  attr_reader :only_paths # filter only commits which touches one of these paths
  attr_reader :name, :before, :after
  attr_reader :fixed

  def initialize(yaml, config_file, default_source)
    @config_file = config_file

    @git = yaml["git"]
    @svn = yaml["svn"]
    @xls = yaml["xls"]
    @csv = yaml["csv"]
    @only_paths = yaml["only"] || []
    @name = yaml["name"] || label.split("/").last
    @before = seconds_in(yaml["before"]) || default_source.before
    @after = seconds_in(yaml["after"]) || default_source.after
    @fixed = yaml["fixed"] || {}

    fail "No source found for #{yaml}" unless git || svn || xls || csv
    fail "Cannot have <= 0 before seconds for #{yaml}" if @before <= 0
    fail "Cannot have <= 0 after seconds for #{yaml}" if @after <= 0
  end

  def revisions
    @revisions ||= begin
      result = if git
        load_git!
      elsif svn
        load_svn!
      elsif xls
        load_xls!
      elsif csv
        load_csv!
      else
        fail "Unknown source #{label}"
      end

      LOG.info "Found #{result.count} revisions in #{label}"
      result
    rescue StandardError => e
      fail "Could not load #{name}: #{e}"
    end
  end

  def git_commit_matches_path?(commit_hash)
    return true if only_paths.empty?

    # Make sure that this commit has touched one of the given paths somehow
    stream_command("#{git_list_paths_command(commit_hash)}") do |stat_line|
      tab_split = stat_line.split("\t", 3)

      if tab_split[0].match?(/\A[0-9]+\Z/)
        return true if only_paths.any? { |path_regex| tab_split[2].match?(path_regex) }
      end
    end

    false
  end

  def git_commit_paths(commit_hash)
    return [] unless config_file.categories.any?

    result = []
    stream_command("#{git_list_paths_command(commit_hash)}") do |stat_line|
      tab_split = stat_line.split("\t", 3)

      if tab_split[0].match?(/\A[0-9]+\Z/)
        result << tab_split[2]
      end
    end

    result
  end

  def load_git!
    LOG.info "Cloning #{git} into #{temp_repository_path}..."
    result = []
    stream_command("#{git_clone_command} && #{git_log_command}") do |line|
      line = line.gsub("\"", "'") # As far as I can tell, git log can't output valid CSV with " in subjects
      begin
        CSV.parse(line).each do |csv|
          commit_hash = csv[0]

          break unless git_commit_matches_path?(commit_hash)

          result << {
            id: csv[0],
            author: csv[1],
            author_date: DateTime.parse(csv[2]),
            committer: csv[3],
            committer_date: DateTime.parse(csv[4]),
            message: csv[5],
            paths: git_commit_paths(commit_hash),
            source: self,
          }.merge(fixed_data)
        end
      rescue CSV::MalformedCSVError
        LOG.warn "Ignoring CSV malformed row: #{line}"
      end
    end
    LOG.debug "Deleting #{temp_repository_path}..." if LOG.debug?
    FileUtils.remove_dir(temp_repository_path)
    result
  end

  def load_svn!
    result = []
    current_result = {}
    stream_command("#{svn_log_command}") do |line|
      line.strip!
      if data = line.match(/r([0-9]+) \| ([^ ]+) \| ([^\|]+) \(([^\|]+)\) \| (.*)/)
        current_result = {
          id: data[1],
          author: data[2],
          author_date: DateTime.parse(data[3]),
          message: data[5],
          source: self,
        }.merge(fixed_data)
      elsif data = line.match(/(.+)/) && current_result[:id]
        current_result[:message] = line
        result << current_result.merge(fixed_data)
        current_result = {}
      end
    end
    result
  end

  def load_xls!
    result = []

    require "spreadsheet"
    sheet = Spreadsheet.open("#{xls_path}")

    sheet.worksheets.each do |worksheet|
      columns = map_headers(worksheet.row(0))

      worksheet.rows.each.with_index do |row, row_id|
        next if row_id == 0

        current_result = {
          id: "#{label}:#{worksheet.name}:#{row_id}",
          source: self,
        }
        columns.each do |cell_id, key|
          current_result[key] = row[cell_id]
        end
        current_result.merge!(fixed_data)
        current_result[:author_date] = DateTime.parse(current_result[:author_date])
        result << current_result
      end
    end
    result
  end

  def map_headers(first_row)
    columns = {}

    first_row.each_with_index do |cell, cell_id|
      if cell.match?(/(modified at|occurred at)/i)
        columns[cell_id] = :author_date
      elsif cell.match?(/(performed by|created by|modified by|author|user)/i)
        columns[cell_id] = :author
      elsif cell.match?(/message/i)
        columns[cell_id] = :message
      elsif cell.match?(/(path|url)/i)
        columns[cell_id] = :paths
      end
    end

    fail "Could not find an author header in #{first_row}" unless columns.values.include?(:author) || has_fixed?("author")
    fail "Could not find a date header in #{first_row}" unless columns.values.include?(:author_date)

    columns
  end

  def load_csv!
    result = []
    columns = "not loaded yet"
    CSV.foreach(csv_path).each.with_index do |row, row_id|
      if row_id == 0
        columns = map_headers(row)
      else
        current_result = {
          id: "#{label}:#{row_id}",
          source: self,
        }

        columns.each do |cell_id, key|
          current_result[key] = row[cell_id]
        end
        current_result.merge!(fixed_data)
        current_result[:author_date] = DateTime.parse(current_result[:author_date])
        result << current_result
      end
    end

    result
  end

  def label
    if git
      "git:#{git}"
    elsif svn
      "svn:#{svn}"
    elsif xls
      "xls:#{xls}"
    elsif csv
      "csv:#{csv}"
    else
      fail "Unknown source #{inspect}"
    end
  end

  private

  def temp_repository_path
    @temp_repository_path ||= "#{Dir.tmpdir}/#{name}-#{Time.now.to_i}"
  end

  def git_clone_command
    "git clone #{git} #{temp_repository_path}"
  end

  def git_log_command
    "cd #{temp_repository_path} && git log --date iso --pretty=format:\"%H\",\"%aE\",\"%ad\",\"%cE\",\"%cd\",\"%s\""
  end

  def git_list_paths_command(commit_hash)
    "cd #{temp_repository_path} && git show #{commit_hash} --numstat"
  end

  def svn_log_command
    "svn log -r 1:HEAD #{svn}"
  end

  def xls_path
    File.join(File.dirname(config_file.path), xls)
  end

  def csv_path
    File.join(File.dirname(config_file.path), csv)
  end

  def has_fixed?(label)
    fixed[label].present?
  end

  def fixed_data
    result = {}
    fixed.each do |key, value|
      result[key.to_sym] = value
    end
    result
  end
end
