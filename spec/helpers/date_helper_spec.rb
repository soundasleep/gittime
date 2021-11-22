require "spec_helper"

describe DateHelper, type: :helper do
  include DateHelper

  describe "#print_date" do
    let(:options) { default_options }
    subject { print_date(date) }

    context "a date" do
      let(:date) { DateTime.parse("2010-01-01 12:34:56 +1200") }
      it { is_expected.to eq "2010-01-01 00:34:56" }

      context "in UTC" do
        let(:date) { DateTime.parse("2010-01-01 12:34:56 +0000") }
        it { is_expected.to eq "2010-01-01 12:34:56" }
      end

      context "in +0300" do
        let(:date) { DateTime.parse("2010-01-01 12:34:56 +0300") }
        it { is_expected.to eq "2010-01-01 09:34:56" }
      end

      context "with a custom date format" do
        let(:options) { default_options.merge({ date_format: "%m-%y" }) }
        it { is_expected.to eq "01-10" }
      end
    end

    context "the default time zone" do
      subject { options[:time_zone] }
      it { is_expected.to eq "UTC" }
    end

    context "with Auckland timezone specified" do
      let(:options) { default_options.merge({ time_zone: "Pacific/Auckland"})}

      context "a date" do
        let(:date) { DateTime.parse("2010-01-01 12:34:56 +1300") }
        it { is_expected.to eq "2010-01-01 12:34:56" }

        context "in UTC" do
          let(:date) { DateTime.parse("2010-01-01 12:34:56 +0000") }
          it { is_expected.to eq "2010-01-02 01:34:56" }
        end

        context "in +0300" do
          let(:date) { DateTime.parse("2010-01-01 12:34:56 +0300") }
          it { is_expected.to eq "2010-01-01 22:34:56" }
        end

        context "with a custom date format" do
          let(:options) { default_options.merge({ date_format: "%m-%y" }) }
          it { is_expected.to eq "12-09" }
        end
      end
    end
  end
end
