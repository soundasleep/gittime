class CommandLineRunner
  attr_reader :options

  def initialize(options:)
    @options = options

    fail "Need config specified with --config flag" unless options[:config]
  end

  def call
    if options[:init]
      if File.exist?(options[:config]) && !options[:overwrite]
        fail "Cannot overwrite #{options[:config]} without --overwrite flag"
      else
        InitConfigFile.new(file: options[:config]).call
      end
    else
      if !File.exist?(options[:config])
        fail "Cannot load #{options[:config]} - you can try init with --init"
      end
      config = ReadConfigFile.new(file: options[:config]).call
      GenerateReports.new(config: config, options: options).call
    end
  end
end
