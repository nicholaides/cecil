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

  describe ".match_ending_pair" do
    it "returns the first pair that matches the end of the string" do
      pair = match_ending_pair("abc", { "b" => "B", "c" => "C", "bc" => "BC" })
      expect(pair).to eq %w[c C]
    end

    it "matches string of any size" do
      pair = match_ending_pair("abcdef", { "b" => "B", "bcdef" => "BCDEF" })
      expect(pair).to eq %w[bcdef BCDEF]
    end

    it "matches empty string if one of the pairs has empty string as an opener" do
      pair = match_ending_pair("abcdef", { "b" => "B", "" => "EMPTY", "c" => "C" })
      expect(pair).to eq ["", "EMPTY"]
    end

    it "returns nil when it doesn't match a pair" do
      pair = match_ending_pair("abcdef", { "b" => "B", "c" => "C" })
      expect(pair).to be_nil
    end

    it "returns nil when the given pairs is empty" do
      pair = match_ending_pair("abcdef", {})
      expect(pair).to be_nil
    end

    it "returns nil when the string is empty even one of the openers is an empty string" do
      pair = match_ending_pair("", { "" => "empty" })
      expect(pair).to be_nil
    end

    it "returns nil when no opener matches, even if an opener overlaps with the source string" do
      pair = match_ending_pair("a", { "aa" => "AA" })
      expect(pair).to be_nil
    end
  end

  describe ".closers" do
    it "returns the closers for the given string" do
      closers = closers("abc", { "b" => "B", "c" => "C" }).to_a
      expect(closers).to eq %w[C B]
    end

    it "returns the closers for the given string, and accepts empty string" do
      closers = closers("abcbb", { "b" => "B", "c" => "C" }).to_a
      expect(closers).to eq %w[B B C B]
    end

    it "yields the closers when given a block" do
      endings = []
      closers("abcbb", { "b" => "B", "c" => "C" }) do |closer|
        endings << closer
      end
      expect(endings).to eq %w[B B C B]
    end
  end
end
