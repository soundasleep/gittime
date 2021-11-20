require "csv"

class Source
  include CommandLineHelper
  include SecondsHelper

  attr_reader :git, :svn
  attr_reader :name, :before, :after

  def initialize(yaml, default_source)
    @git = yaml["git"]
    @svn = yaml["svn"]
    @name = yaml["name"] || (@git || @svn).split("/").last
    @before = seconds_in(yaml["before"]) || default_source.before
    @after = seconds_in(yaml["after"]) || default_source.after

    fail "No source found for #{yaml}" unless git || svn
    fail "Cannot have <= 0 before seconds for #{yaml}" if @before <= 0
    fail "Cannot have <= 0 after seconds for #{yaml}" if @after <= 0
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
            source: self,
          }
        end
      end
      LOG.info "Found #{result.count} revisions in git:#{git}"
      LOG.debug "Deleting #{temp_repository_path}..." if LOG.debug?
      FileUtils.remove_dir(temp_repository_path)
      result
    elsif svn
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
          }
        elsif data = line.match(/(.+)/) && current_result[:id]
          current_result[:message] = line
          result << current_result
          current_result = {}
        end
      end
      LOG.info "Found #{result.count} revisions in svn:#{svn}"
      result
    else
      fail "Unknown source #{self}"
    end
  end

  def label
    if git
      "git:#{git}"
    elsif svn
      "svn:#{svn}"
    else
      fail "Unknown source #{self}"
    end
  end

  private

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
