require "spec_helper"

describe "integration", type: :integration do
  let(:config) { "#{File.dirname(__FILE__)}/#{config_filename}" }
  let(:options) { default_options.merge({ config: config, output: output_path }) }
  let(:result) { CommandLineRunner.new(options: options).call }

  let(:filenames) { result.map { |result| result[:filename] } }

  let(:blocks) { result.select { |result| result[:filename] == "blocks.csv" }.only }
  let(:lines) { blocks[:data].size }

  describe "a local config path" do
    let(:output_path) { "../../output" }
    let(:options) { default_options.merge({ config: config, output: output_path }) }

    describe "an ical file" do
      let(:config_filename) { "config.ical.yml" }

      it "can be run against a repository" do
        expect(result).to_not eq nil
        expect(filenames).to include "revisions.csv"
        expect(filenames).to include "revisions-with-authors.csv"
        expect(filenames).to include "blocks.csv"
        expect(filenames).to include "blocks-by-month.csv"
        expect(filenames).to include "work-by-month.csv"
      end

      it "has calculated an exact number of events" do
        expect(lines).to eq 20 # exact
      end

      describe "with ignore filters" do
        let(:config_filename) { "config.ical.with-ignore.yml" }

        it "has calculated an exact number of events" do
          expect(lines).to eq 16 # exact
        end
      end

      describe "with only filters" do
        let(:config_filename) { "config.ical.with-only.yml" }

        it "has calculated an exact number of events" do
          expect(lines).to eq 4 # exact
        end
      end
    end
  end
end
