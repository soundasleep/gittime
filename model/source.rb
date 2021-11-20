require "chronic_duration"
require "csv"

class Source
  include CommandLineHelper

  attr_reader :git, :svn
  attr_reader :name, :before, :between, :after

  def initialize(yaml)
    @git = yaml["git"]
    @svn = yaml["svn"]
    @name = yaml["name"] || (@git || @svn).split("/").last
    @before = seconds_in(yaml["before"]) || default_before
    @between = seconds_in(yaml["between"]) || default_between
    @after = seconds_in(yaml["after"]) || default_after

    fail "No source found for #{yaml}" unless git || svn
  end

  def revisions
    @revisions ||= if git
      LOG.info "Cloning #{git} into #{temp_repository_path}..."
      result = []
      stream_command("#{git_clone_command} && #{git_log_command}") do |line|
        CSV.parse(line).each do |csv|
          result << {
            id: csv[0],
            author: csv[1],
            author_date: DateTime.parse(csv[2]),
            committer: csv[3],
            committer_date: DateTime.parse(csv[4]),
            message: csv[5],
            source: git,
          }
        end
      end
      LOG.info "Found #{result.count} revisions in git:#{git}"
      LOG.debug "Deleting #{temp_repository_path}..." if LOG.debug?
      FileUtils.remove_dir(temp_repository_path)
      result
    elsif svn
      result = []
      stream_command("#{svn_log_command}") do |line|
        if data = line.match(/r([0-9]+) \| ([^ ]+) \| ([^\|]+) \(([^\|]+)\) \| /)
          result << {
            id: data[1],
            author: data[2],
            author_date: DateTime.parse(data[3]),
            message: data[4],
            source: svn,
          }
        end
      end
      LOG.info "Found #{result.count} revisions in svn:#{svn}"
      result
    else
      fail "Unknown source #{self}"
    end
  end

  private

  def seconds_in(string)
    return 0 if string.blank?
    ChronicDuration::parse(string)
  end

  def temp_repository_path
    @temp_repository_path ||= "#{Dir.tmpdir}/#{name}-#{Time.now.to_i}"
  end

  def git_clone_command
    "git clone #{git} #{temp_repository_path} -q"
  end

  def git_log_command
    "cd #{temp_repository_path} && git log --date iso --pretty=format:\"%H\",\"%aE\",\"%ad\",\"%cE\",\"%cd\",\"%s\""
  end

  def svn_log_command
    "svn log -r 1:HEAD #{svn}"
  end
end
