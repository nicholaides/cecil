require "cecil/placeholder"

RSpec.describe Cecil::Placeholder do
  describe "#with" do
    it "creates a new placeholder with values replaced by the arguments" do
      original = described_class.new("username", 1, 4)
      updated = original.with(ident: "USERNAME")
      expect(updated.to_h).to eq({ ident: "USERNAME", offset_start: 1, offset_end: 4 })
    end
  end

  describe "#transform_key" do
    it "creates a new placeholder one value transformed by the given block" do
      original = described_class.new("username", 1, 4)
      updated = original.transform_key(:ident, &:upcase)
      expect(updated.to_h).to eq({ ident: "USERNAME", offset_start: 1, offset_end: 4 })
    end
  end
end
