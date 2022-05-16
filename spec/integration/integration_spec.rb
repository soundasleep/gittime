require "spec_helper"

describe "integration", type: :integration do
  let(:config) { "config.init.yml" }
  let(:options) { default_options.merge({ config: config }) }
  let(:result) { CommandLineRunner.new(options: options).call }

  let(:filenames) { result.map { |result| result[:filename] } }

  let(:blocks) { result.select { |result| result[:filename] == "blocks.csv" }.only }
  let(:lines) { blocks[:data].size }

  it "can be run against a repository" do
    expect(result).to_not eq nil
    expect(filenames).to include "revisions.csv"
    expect(filenames).to include "revisions-with-authors.csv"
    expect(filenames).to include "blocks.csv"
    expect(filenames).to include "blocks-by-month.csv"
    expect(filenames).to include "work-by-month.csv"
  end

  it "has calculated at least ten blocks of work" do
    expect(lines).to be >= 10
  end

  describe "a local config path" do
    let(:config) { "#{File.dirname(__FILE__)}/#{config_filename}" }
    let(:output_path) { "../../output" }
    let(:options) { default_options.merge({ config: config, output: output_path }) }

    describe "just a git repository" do
      let(:config_filename) { "config.git.yml" }

      it "can be run against a repository" do
        expect(result).to_not eq nil
        expect(filenames).to include "revisions.csv"
        expect(filenames).to include "revisions-with-authors.csv"
        expect(filenames).to include "blocks.csv"
        expect(filenames).to include "blocks-by-month.csv"
        expect(filenames).to include "work-by-month.csv"
      end

      it "has calculated at least four blocks of work" do
        # This is less than above because this is only looking at a single git repo
        expect(lines).to be >= 4
      end
    end

    describe "path-based filtering" do
      let(:config_filename) { "config.git.path-filtering.yml" }

      it "can be run against a repository" do
        expect(result).to_not eq nil
        expect(filenames).to include "revisions.csv"
        expect(filenames).to include "revisions-with-authors.csv"
        expect(filenames).to include "blocks.csv"
        expect(filenames).to include "blocks-by-month.csv"
        expect(filenames).to include "work-by-month.csv"
      end

      it "has calculated no more than three blocks of work" do
        # Path filtering should have reduced the amount of work tracked
        expect(lines).to be <= 3
      end
    end
  end
end
