require_relative "../helpers/reindent_helpers"

RSpec.describe Cecil::Text do
  include Cecil::Text

  describe ".scan_for_re_matches" do
    it "returns matches" do
      matches = scan_for_re_matches("a b c d", /\w+/)
      match_strs = matches.map { _1[0] }
      expect(match_strs).to eq %w[a b c d]
    end

    it "returns empty array when there are no matches" do
      matches = scan_for_re_matches("a b c d", /XYZ/)
      expect(matches).to eq []
    end
  end
end
