require "spec_helper"

describe "integration", type: :integration do
  let(:config) { "config.init.yml" }
  let(:options) { default_options.merge({ config: config }) }
  let(:result) { CommandLineRunner.new(options: options).call }

  let(:filenames) { result.map { |result| result[:filename] } }

  let(:blocks) { result.select { |result| result[:filename] == "blocks.csv" }.only }
  let(:lines) { blocks[:data].size }
  let(:authors) { result.select { |result| result[:filename] == "authors.csv" }.only[:data] }

  it "can be run against a repository" do
    expect(result).to_not eq nil
    expect(filenames).to include "revisions.csv"
    expect(filenames).to include "revisions-with-authors.csv"
    expect(filenames).to include "blocks.csv"
    expect(filenames).to include "blocks-by-month.csv"
    expect(filenames).to include "work-by-month.csv"
    expect(filenames).to include "authors.csv"
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

      describe "for sample config.init.yml" do
        let(:config_filename) { "../../config.init.yml" }

        it "can be run against a repository" do
          expect(result).to_not eq nil
          expect(filenames).to include "revisions.csv"
          expect(filenames).to include "revisions-with-authors.csv"
          expect(filenames).to include "blocks.csv"
          expect(filenames).to include "blocks-by-month.csv"
          expect(filenames).to include "work-by-month.csv"
          expect(filenames).to include "authors.csv"
        end

        it "has calculated at least 5 authors" do
          expect(authors.size).to be >= 5
        end

        let(:jevon_aliases) { authors.select { |row| row.first == "jevon" } }
        it "has identified three different versions of 'jevon'" do
          expect(jevon_aliases.size).to eq 3
          expect(jevon_aliases[0]).to eq ["jevon", "Jevon Wright"]
          expect(jevon_aliases[1]).to eq ["jevon", "jevon.wright"]
          expect(jevon_aliases[2]).to eq ["jevon", "jevon@jevon.org"]
        end
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
          expect(filenames).to include "authors.csv"
        end

        it "has calculated at least four blocks of work" do
          # Should be the same as above
          expect(lines).to be >= 4
        end

        it "has calculated all authors, filtered and non-filtered" do
          expect(authors.only).to eq ["jevon", "jevon@jevon.org"]
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
          expect(filenames).to include "authors.csv"
        end

        it "has calculated zero blocks of work" do
          # However we're filtering against a committer that doesn't exist
          expect(lines).to eq 0
        end

        it "has calculated all authors, filtered and non-filtered" do
          expect(authors.only).to eq ["jevon", "jevon@jevon.org"]
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
        expect(filenames).to include "authors.csv"
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
        expect(filenames).to include "authors.csv"
      end

      it "has calculated no more than three blocks of work" do
        # Path filtering should have reduced the amount of work tracked
        expect(lines).to be <= 3
      end
    end
  end
end
