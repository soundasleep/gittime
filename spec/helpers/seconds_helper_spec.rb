require "spec_helper"

describe SecondsHelper, type: :helper do
  include SecondsHelper

  describe "#seconds_in" do
    subject { seconds_in(string) }

    context "1 hour" do
      let(:string) { "1 hour" }
      it { is_expected.to eq 60 * 60 }
    end

    context "30 seconds" do
      let(:string) { "30 seconds" }
      it { is_expected.to eq 30 }
    end
  end
end
