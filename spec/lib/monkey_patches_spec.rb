require "spec_helper"

describe "monkey_patches", type: :lib do
  describe "Array.only" do
    it "works on arrays of one" do
      expect(["hello"].only).to eq "hello"
    end

    it "fails on empty arrays" do
      expect { [].only }.to raise_error(Array::ArrayOnlyError)
    end

    it "fails on bigger arrays" do
      expect { [1, 2].only }.to raise_error(Array::ArrayOnlyError)
    end
  end
end
