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

    describe "output to an arbitrary directory" do
      let(:config_filename) { "config.git.yml" }
      let(:output_path) { "./output" }

      it "does not crash" do
        expect(result).to_not eq nil
      end

      it "has calculated at least ten blocks of work" do
        expect(lines).to be >= 10
      end

      describe "with cache options" do
        let(:options) { default_options.merge({ cache: ".cache/", config: config, output: output_path }) }

        it "does not crash" do
          expect(result).to_not eq nil
        end

        it "creates cache directories" do
          expect(Dir.exist?("#{File.dirname(__FILE__)}/.cache")).to eq true
          expect(Dir.exist?("#{File.dirname(__FILE__)}/.cache/gittime")).to eq true
        end

        it "can reuse the cache directories the second time around" do
          expect(Dir.exist?("#{File.dirname(__FILE__)}/.cache/gittime")).to eq true

          result2 = CommandLineRunner.new(options: options).call

          expect(result2).to_not eq nil
          expect(Dir.exist?("#{File.dirname(__FILE__)}/.cache/gittime")).to eq true
        end
      end

      describe "with env options" do
        let(:config_filename) { "config.git.env.yml" }
        let(:env_filename) { ".config.git.env.yml" }
        let(:options) { default_options.merge({ config: config, output: output_path, env: "#{File.dirname(__FILE__)}/#{env_filename}" }) }

        it "does not crash" do
          expect(result).to_not eq nil
        end

        it "has calculated at least ten blocks of work" do
          expect(lines).to be >= 10
        end
      end
    end

    describe "merging configurations together" do
      let(:config_filename) { "config.merge.yml" }
      let(:output_path) { "./output" }

      it "does not crash" do
        expect(result).to_not eq nil
      end
    end

    # we need named sources so we can merge e.g. two identical sources together
    describe "named sources" do
      let(:config_filename) { "config.named.yml" }
      let(:output_path) { "./output" }

      it "does not crash" do
        expect(result).to_not eq nil
      end
    end

    describe "filtered authors" do
      describe "with results" do
        let(:config_filename) { "config.filtered-authors.positive.yml" }

        it "can be run against a repository" do
          expect(result).to_not eq nil
          expect(filenames).to include "revisions.csv"
          expect(filenames).to include "revisions-with-authors.csv"
          expect(filenames).to include "blocks.csv"
          expect(filenames).to include "blocks-by-month.csv"
          expect(filenames).to include "work-by-month.csv"
        end

        it "has calculated at least four blocks of work" do
          # Should be the same as above
          expect(lines).to be >= 4
        end
      end

      describe "without results" do
        let(:config_filename) { "config.filtered-authors.negative.yml" }

        it "can be run against a repository" do
          expect(result).to_not eq nil
          expect(filenames).to include "revisions.csv"
          expect(filenames).to include "revisions-with-authors.csv"
          expect(filenames).to include "blocks.csv"
          expect(filenames).to include "blocks-by-month.csv"
          expect(filenames).to include "work-by-month.csv"
        end

        it "has calculated zero blocks of work" do
          # However we're filtering against a committer that doesn't exist
          expect(lines).to eq 0
        end
      end
    end

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

    describe "category filtering" do
      let(:config_filename) { "config.git.categories.yml" }

      it "can be run against a repository" do
        expect(result).to_not eq nil
        expect(filenames).to include "revisions.csv"
        expect(filenames).to include "revisions-with-authors.csv"
        expect(filenames).to include "blocks.csv"
        expect(filenames).to include "blocks-by-month.csv"
        expect(filenames).to include "work-by-month.csv"
      end

      it "has calculated category weightings for each report" do
        result.each do |report|
          ["test %", "config %", "docs %", "other %"].each do |category|
            expect(report[:headers]).to include(category), "#{report[:filename]} should have category key #{category} in #{report[:headers]}"
          end
        end
      end

      let(:report) { result.select { |r| r[:filename].include?(filename) }.only }

      describe "revisions.csv" do
        let(:filename) { "revisions.csv" }

        let(:header_test) { 5 }
        let(:header_config) { 6 }
        let(:header_docs) { 7 }
        let(:header_other) { 8 }

        it "has headers in the correct indices" do
          expect(report[:headers][header_test]).to eq "test %"
          expect(report[:headers][header_config]).to eq "config %"
          expect(report[:headers][header_docs]).to eq "docs %"
          expect(report[:headers][header_other]).to eq "other %"
        end

        let(:commit_hash) { "c649e87a36a0c96ad2df2add6ecb9a22b7a48f4a" }
        describe "c649e87a36a0c96ad2df2add6ecb9a22b7a48f4a" do
          let(:report_line) { report[:data].select { |line| line[0] == commit_hash }.only }

          let(:test_pct) { report_line[header_test] }
          let(:config_pct) { report_line[header_config] }
          let(:docs_pct) { report_line[header_docs] }
          let(:other_pct) { report_line[header_other] }

          it "has appropriate weightings for each %" do
            # c649e87a36a0c96ad2df2add6ecb9a22b7a48f4a:
            # - config.init.yml --> config
            # - model/config_file.rb --> other
            # - model/source.rb --> other
            # - spec/integration/config.git.path-filtering.yml --> test
            # - spec/integration/config.git.yml --> test
            # - spec/integration/integration_spec.yml --> test

            expect(test_pct).to eq(3.0 / 6), "in #{report_line}"
            expect(config_pct).to eq(1.0 / 6), "in #{report_line}"
            expect(docs_pct).to eq(0.0), "in #{report_line}"
            expect(other_pct).to eq(2.0 / 6), "in #{report_line}"
          end
        end
      end

      describe "blocks.csv" do
        let(:filename) { "blocks.csv" }

        let(:header_test) { 9 }
        let(:header_config) { 10 }
        let(:header_docs) { 11 }
        let(:header_other) { 12 }

        it "has headers in the correct indices" do
          expect(report[:headers][header_test]).to eq("test %"), "in #{report[:headers]}"
          expect(report[:headers][header_config]).to eq("config %"), "in #{report[:headers]}"
          expect(report[:headers][header_docs]).to eq("docs %"), "in #{report[:headers]}"
          expect(report[:headers][header_other]).to eq("other %"), "in #{report[:headers]}"
        end

        describe "the first block" do
          let(:report_line) { report[:data].first }

          let(:test_pct) { report_line[header_test] }
          let(:config_pct) { report_line[header_config] }
          let(:docs_pct) { report_line[header_docs] }
          let(:other_pct) { report_line[header_other] }

          it "has appropriate weightings for each %" do
            expect(test_pct).to eq(0.25), "in #{report_line}"
            expect(config_pct).to eq(0), "in #{report_line}"
            expect(docs_pct).to eq(0), "in #{report_line}"
            expect(other_pct).to eq(0.75), "in #{report_line}"
          end
        end
      end

      describe "work-by-month.csv" do
        let(:filename) { "work-by-month.csv" }

        let(:header_test) { 7 }
        let(:header_config) { 8 }
        let(:header_docs) { 9 }
        let(:header_other) { 10 }

        it "has headers in the correct indices" do
          expect(report[:headers][header_test]).to eq("test %"), "in #{report[:headers]}"
          expect(report[:headers][header_config]).to eq("config %"), "in #{report[:headers]}"
          expect(report[:headers][header_docs]).to eq("docs %"), "in #{report[:headers]}"
          expect(report[:headers][header_other]).to eq("other %"), "in #{report[:headers]}"
        end

        describe "the first block" do
          let(:report_line) { report[:data].first }

          let(:test_pct) { report_line[header_test] }
          let(:config_pct) { report_line[header_config] }
          let(:docs_pct) { report_line[header_docs] }
          let(:other_pct) { report_line[header_other] }

          it "has appropriate weightings for each %" do
            expect(test_pct.round(3)).to eq(0.109), "in #{report_line}"
            expect(config_pct.round(3)).to eq(0.057), "in #{report_line}"
            expect(docs_pct.round(3)).to eq(0.139), "in #{report_line}"
            expect(other_pct.round(3)).to eq(0.695), "in #{report_line}"
          end
        end
      end
    end
  end
end
