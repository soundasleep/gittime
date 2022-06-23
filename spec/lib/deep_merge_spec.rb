require "spec_helper"

describe "deep_merge", type: :lib do
  subject { deep_merge(a, b) }

  describe "simple arrays" do
    let(:a) { [1] }
    let(:b) { [2] }

    it { is_expected.to eq([1, 2]) }
  end

  describe "simple hashes" do
    let(:a) { { a: 1 } }
    let(:b) { { b: 2 } }

    it { is_expected.to eq({ a: 1, b: 2 }) }
  end

  describe "simple hashes of arrays" do
    let(:a) { { a: [1, 2] } }
    let(:b) { { a: [2, 3] } }

    # NOTE it does not add additional values, 2 is merged
    it { is_expected.to eq({ a: [1, 2, 3] }) }
  end

  describe "two simple hashes with different array values" do
    let(:a) { { a: [ 1 ], b: [ 1 ] } }
    let(:b) { { a: [ 2 ], b: [ 2 ] } }

    it { is_expected.to eq({ a: [1, 2], b: [1, 2] }) }
  end

  describe "a hash with a hash" do
    let(:a) { { a: { a: 1, b: 2 } } }
    let(:b) { { a: { b: 3, c: 4 } } }

    # note b: 2, not b: 3
    it { is_expected.to eq({ a: { a: 1, b: 2, c: 4 }}) }
  end

  describe "a hash with a hash with a hash" do
    let(:a) { { z: { a: { a: 1, b: 2 } } } }
    let(:b) { { z: { a: { c: 4 } } } }

    # note b: 2, not b: 3
    it { is_expected.to eq({ z: { a: { a: 1, b: 2, c: 4 }}}) }
  end

  describe "a hash with a hash with an array" do
    let(:a) { { z: { a: { a: [1, 2] } } } }
    let(:b) { { z: { a: { a: [2, 3] } } } }

    it { is_expected.to eq({ z: { a: { a: [1, 2, 3] }}}) }
  end
end
