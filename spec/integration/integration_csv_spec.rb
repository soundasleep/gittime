require "spec_helper"

describe "integration csv", type: :integration do
  let(:config) { "#{File.dirname(__FILE__)}/#{config_filename}" }
  let(:output_path) { "../../output" }
  let(:options) { default_options.merge({ config: config, output: output_path }) }
  let(:result) { CommandLineRunner.new(options: options).call }

  let(:blocks) { result.select { |result| result[:filename] == "work-by-month.csv" }.only }
  let(:lines) { blocks[:data].size }

  let(:report) { result.select { |r| r[:filename].include?(filename) }.only }

  describe "a normal CSV source" do
    let(:config_filename) { "config.csv.yml" }

    it "the config file exists" do
      expect(File.exist?(config)).to be true
    end

    it "can be run against a repository" do
      expect(result).to_not eq nil
    end

    it "has calculated one month of work" do
      expect(lines).to eq 1
    end
  end

  describe "a CSV source with no fixed author defined" do
    let(:config_filename) { "config.csv.no-fixed-author.yml" }

    it "the config file exists" do
      expect(File.exist?(config)).to be true
    end

    it "normally crashes" do
      begin
        expect(result).to be nil
      rescue
        # expected
      end
    end
  end

  describe "a CSV source with a specific author field" do
    let(:config_filename) { "config.csv.with-author.yml" }

    it "can be run against a repository" do
      expect(result).to_not eq nil
    end

    it "has calculated three months of work" do
      expect(lines).to eq 3
    end
  end

  describe "a CSV source which occasionally has gaps" do
    let(:config_filename) { "config.csv.with-author.with-gaps.yml" }

    it "the config file exists" do
      expect(File.exist?(config)).to be true
    end

    it "normally crashes" do
      begin
        expect(result).to be nil
      rescue
        # expected
      end
    end

    describe "when we provide a fallback in the config" do
      let(:config_filename) { "config.csv.with-author.with-gaps.fallback.yml" }

      it "can be run against a repository" do
        expect(result).to_not eq nil
      end

      it "has calculated three months of work for jevon, and one for anonymous" do
        expect(lines).to eq 3 + 1
      end
    end
  end
end
