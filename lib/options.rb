require "optparse"

def default_options
  {
    init: false,
    overwrite: false,
    output: "output/",
    date_format: "%F %T",
    time_zone: "UTC",
    level: "debug",
    colours: true,
    cache: nil,
  }
end

def load_command_line_options
  options = default_options
  log_levels = ["debug", "info", "warn", "error", "fatal", "unknown"]
  log_levels.concat log_levels.map(&:upcase)

  OptionParser.new do |opts|
    opts.banner = "Usage: generate.rb [options]"

    opts.separator ""
    opts.separator "Specific options:"

    opts.on("-c", "--config FILE.YML", "Config file to use") do |file|
      options[:config] = file
    end

    opts.on("-i", "--init", "Initialise a new config file") do
      options[:init] = true
    end

    opts.on("--overwrite", "Overwrite any existing config files") do
      options[:overwrite] = true
    end

    opts.on("--cache DIR/", "Cache git repositories in this directory, relative to config file (default: `#{default_options[:cache]}`)") do |path|
      fail "Expected / at end of cache path" unless path[-1] == "/"
      options[:cache] = path
    end

    opts.separator ""
    opts.separator "Report options:"

    opts.on("-o", "--output DIR/", "Write reports to this directory, relative to config file (default: `#{default_options[:output]}`)") do |path|
      fail "Expected / at end of output path" unless path[-1] == "/"
      options[:output] = path
    end

    opts.on("--date_format FORMAT", "Date format to print using strftime (default: `#{default_options[:date_format]}`)") do |string|
      options[:date_format] = string
    end

    opts.on("--tz ZONE", "--timezone ZONE", "Convert all dates into this timezone (default: `#{default_options[:time_zone]}`)") do |string|
      options[:time_zone] = string
    end

    opts.separator ""
    opts.separator "Common options:"

    opts.on("--level LEVEL", log_levels, "Logging level severity (default: `#{default_options[:level]}`)") do |level|
      options[:level] = level.downcase
    end

    opts.on("--colours", "Use colour logging") do |c|
      options[:colours] = c
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

    opts.on_tail("--version", "Show version") do
      puts ::Version.join(".")
      exit
    end
  end.parse!

  $command_line_options = options
end

def options
  $command_line_options
end

unless $running_in_rspec
  load_command_line_options
  raise "Need to provide a config with --config" unless options[:config]
end
