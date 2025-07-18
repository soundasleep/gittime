require "csv"

class Source
  include CommandLineHelper
  include SecondsHelper

  attr_reader :config_file
  attr_reader :options

  attr_reader :git, :svn, :xls, :csv, :ical
  attr_reader :only_paths # filter only commits which touches one of these paths
  attr_reader :ignore_paths # ignore ical events that match this filter anywhere
  attr_reader :name, :before, :after
  attr_reader :fixed, :fallback

  def initialize(yaml, config_file, default_source, options)
    @config_file = config_file
    @options = options

    @git = yaml["git"]
    @svn = yaml["svn"]
    @xls = yaml["xls"]
    @csv = yaml["csv"]
    @ical = yaml["ical"]
    @only_paths = yaml["only"] || []
    @ignore_paths = yaml["ignore"] || []
    @name = yaml["name"] || label.split("/").last
    @before = seconds_in(yaml["before"]) || default_source.before
    @after = seconds_in(yaml["after"]) || default_source.after
    @fixed = yaml["fixed"] || {}
    @fallback = yaml["fallback"] || {}

    fail "No source found for #{yaml}" unless git || svn || xls || csv || ical
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
      elsif ical
        load_ical!
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

  def load_git!
    LOG.info "Cloning #{git} into #{possibly_cached_repository_path}..."
    result = []

    stream_command("#{git_clone_command}") do |line|
      # ignore any output from clone/cd/pull
    end

    stream_command("#{git_log_command}") do |line|
      line = line.gsub("\"", "'") # As far as I can tell, git log can't output valid CSV with " in subjects
      begin
        CSV.parse(line).each do |csv|
          commit_hash = csv[0]

          next unless git_commit_matches_path?(commit_hash)

          current_result = {
            id: csv[0],
            author: csv[1],
            author_date: DateTime.parse(csv[2]),
            committer: csv[3],
            committer_date: DateTime.parse(csv[4]),
            message: csv[5],
            source: self,
          }.merge(fixed_data)

          apply_fallbacks!(current_result)

          result << current_result
        end
      rescue CSV::MalformedCSVError
        LOG.warn "Ignoring CSV malformed row: #{line}"
      end
    end

    unless options[:cache]
      LOG.debug "Deleting #{possibly_cached_repository_path}..." if LOG.debug?
      FileUtils.remove_dir(possibly_cached_repository_path)
    end
    result
  end

  def load_svn!
    fail "SVN sources do not yet support path filtering" if only_paths && only_paths.any?

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

        apply_fallbacks!(current_result)
      elsif data = line.match(/(.+)/) && current_result[:id]
        current_result[:message] = line
        current_result.merge!(fixed_data)

        # TODO support filtering paths on svn (would need to check out each revision)

        result << current_result
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
        next if row[0].nil? # e.g. an empty line

        current_result = {
          id: "#{label}:#{worksheet.name}:#{row_id}",
          source: self,
        }
        columns.each do |cell_id, key|
          current_result[key] = row[cell_id]
        end
        current_result.merge!(fixed_data)

        apply_fallbacks!(current_result)

        fail "no author_date found in xls row #{current_result[:id]}" if current_result[:author_date].nil?
        begin
          current_result[:author_date] = DateTime.parse(current_result[:author_date])
        rescue StandardError => e
          fail "Could not parse '#{current_result[:author_date]}' on row #{row_id}: #{e}"
        end

        fail "no author found in xls row #{current_result[:id]}" if current_result[:author].nil?

        next unless result_matches_filter?(current_result)
        result << current_result
      end
    end
    result
  end

  def apply_fallbacks!(current_result)
    if current_result[:author].nil? || current_result[:author].empty?
      current_result[:author] = fallback["author"]
    end

    current_result
  end

  def result_matches_filter?(current_result)
    fail "no path provided to filter against #{only_paths}" if only_paths.any? && !current_result[:paths]

    return true if only_paths.empty?

    only_paths.each do |path_regex|
      return true if "#{current_result[:paths]}".match?(path_regex)
    end

    return false
  end

  def map_headers(first_row)
    columns = {}

    first_row.each_with_index do |cell, cell_id|
      next if cell.nil?

      if cell.match?(/(modified at|occurred at|publication date|pubdate|last edited time)/i)
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

        apply_fallbacks!(current_result)

        current_result[:author_date] = DateTime.parse(current_result[:author_date])

        next unless result_matches_filter?(current_result)

        result << current_result
      end
    end

    result
  end

  def load_ical!
    require "icalendar"
    require "open-uri"

    result = []
    URI.open(ical) do |input|
      Icalendar::Calendar.parse(input).each do |cal|
        cal.events.each do |event|
          next unless event.dtstart && event.dtend

          event_length = event.dtend.to_datetime - event.dtstart.to_datetime # in seconds

          # don't include events that are longer than 12 hours, that's probably
          # not a legitimate event to include, or something has broken.
          # TODO add this as a config option
          next if event_length.seconds > 12 * 60 * 60

          current_result = {
            id: event.uid,
            author: "#{event.organizer}", # force to_s for URI:MailTo
            author_date: strip_timezone(event.dtstart),
            event_length: event_length,
            message: "#{event.summary} #{event.description}",
            source: self,
          }.merge(fixed_data)

          apply_fallbacks!(current_result)

          # should we skip this event?
          next if should_ignore?(current_result)
          next unless should_include?(current_result)

          result << current_result
        end
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
    elsif ical
      "ical:#{ical}"
    else
      fail "Unknown source #{inspect}"
    end
  end

  private

  # this is a horrible hack that strips the timezone information from
  # a given datetime (which probably _does_ have timezone information)
  def strip_timezone(time)
    DateTime.parse(time.to_datetime.strftime("%Y-%m-%d %H:%M:%S +00:00"))
  end

  def should_ignore?(result)
    return false if ignore_paths.empty?

    all_components = "#{result[:id]} #{result[:author]} #{result[:author_date]} #{result[:message]}"
    ignore_paths.any? do |path_regex|
      all_components.match?(path_regex)
    end
  end

  def should_include?(result)
    return true if only_paths.empty?

    all_components = "#{result[:id]} #{result[:author]} #{result[:author_date]} #{result[:message]}"
    only_paths.any? do |path_regex|
      all_components.match?(path_regex)
    end
  end

  def possibly_cached_repository_path
    @possibly_cached_repository_path ||= if options[:cache]
      File.join(File.dirname(config_file.path), options[:cache], repository_name)
    else
      "#{Dir.tmpdir}/#{name}-#{Time.now.to_i}"
    end
  end

  def git_clone_command
    if options[:cache] && Dir.exist?(possibly_cached_repository_path)
      "cd #{possibly_cached_repository_path} && git reset --hard && git clean -f && git pull"
    else
      "git clone #{git} #{possibly_cached_repository_path}"
    end
  end

  def git_log_command
    "cd #{possibly_cached_repository_path} && git log --date iso --pretty=format:\"%H\",\"%aE\",\"%ad\",\"%cE\",\"%cd\",\"%s\""
  end

  def git_list_paths_command(commit_hash)
    "cd #{possibly_cached_repository_path} && git show #{commit_hash} --numstat"
  end

  def svn_log_command
    "svn log -r 1:HEAD \"#{svn}\""
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

  def repository_name
    (git || svn || xls || csv).split("/").last or fail "could not find repository name for #{label}"
  end

  def fixed_data
    result = {}
    fixed.each do |key, value|
      result[key.to_sym] = value
    end
    result
  end
end
