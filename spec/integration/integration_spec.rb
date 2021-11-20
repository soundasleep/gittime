require "spec_helper"

describe "integration", type: :integration do
  let(:config) { "config.init.yml" }
  let(:options) { default_options.merge({ config: config }) }
  let(:result) { CommandLineRunner.new(options: options).call }

  let(:filenames) { result.map { |result| result[:filename] } }

  it "can be run against a repository" do
    expect(result).to_not eq nil
    expect(filenames).to include "revisions.csv"
    expect(filenames).to include "revisions-with-authors.csv"
    expect(filenames).to include "blocks.csv"
    expect(filenames).to include "blocks-by-month.csv"
    expect(filenames).to include "work-by-month.csv"
  end
end
