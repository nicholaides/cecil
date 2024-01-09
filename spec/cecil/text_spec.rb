require_relative "../helpers/reindent_helpers"
require "cecil/placeholder"

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

  describe ".replace" do
    let(:template) { "class CLASS extends PARENT export CLASS" }
    let(:placeholders) do
      [
        Cecil::Placeholder.new("CLASS", 6, 11),
        Cecil::Placeholder.new("PARENT", 20, 26),
        Cecil::Placeholder.new("CLASS", 34, 39)
      ]
    end

    it "replaces the template string with the values of the placeholders" do
      result = replace(template, placeholders, { CLASS: "MyClass", PARENT: "my_parent" })
      expect(result).to eq "class MyClass extends my_parent export MyClass"
    end

    it "accepts strings as keys" do
      result = replace(template, placeholders, { "CLASS" => "MyClass", "PARENT" => "my_parent" })
      expect(result).to eq "class MyClass extends my_parent export MyClass"
    end
  end

  describe ".interpolate_named" do
    let(:template) { "class $class<$generic> extends $parent export $class" }
    let(:placeholders) { Cecil::Syntax.new.scan_for_placeholders(template) }

    it "replaces placeholders" do
      values = { class: "MyClass", parent: "my_parent", generic: "T" }
      result = interpolate_named(template, placeholders, values)
      expect(result).to eq "class MyClass<T> extends my_parent export MyClass"
    end

    it "replaces placeholders, accepting string keys" do
      values = { "class" => "MyClass", parent: "my_parent", generic: "T" }
      result = interpolate_named(template, placeholders, values)
      expect(result).to eq "class MyClass<T> extends my_parent export MyClass"
    end

    it "errors when it doesn't provide every placeholder" do
      values = { class: "MyClass" }
      expect { interpolate_named(template, placeholders, values) }.to raise_error do |error|
        expect(error.message).to match(/mismatch/i)
        expect(error.message).to include("parent")
        expect(error.message).to include("generic")

        expect(error.message).not_to include("class")
      end
    end

    it "errors when it provides extra placeholders" do
      values = { class: "MyClass", parent: "my_parent", generic: "T", other: "thing" }
      expect { interpolate_named(template, placeholders, values) }.to raise_error do |error|
        expect(error.message).to match(/mismatch/i)
        expect(error.message).to include("other")

        expect(error.message).not_to include("parent")
        expect(error.message).not_to include("generic")
        expect(error.message).not_to include("class")
      end
    end
  end
end
