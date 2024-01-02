RSpec.describe Cecil::Text do
  describe ".scan_for_re_matches" do
    it "returns matches" do
      matches = Cecil::Text.scan_for_re_matches("a b c d", /\w+/)
      match_strs = matches.map { _1[0] }
      expect(match_strs).to eq %w[a b c d]
    end
  end
end
