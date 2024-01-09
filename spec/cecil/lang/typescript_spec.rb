require "cecil/lang/typescript"

RSpec.describe Cecil::Lang::TypeScript do
  it "indents with 2 spaces"
  it "does not indent ambigous lines"

  describe Cecil::Lang::TypeScript::Helpers do
    include described_class

    describe "t" do
      it "joins items with ' | '" do
        expect(t(%w[a b c])).to eq "a | b | c"
      end
      it "converts inputs to strings" do
        expect(t(["a", "b", :c])).to eq "a | b | c"
      end
      it "removes nils" do
        expect(t(["a", nil, "b", :c])).to eq "a | b | c"
      end
      it "accepts single item" do
        expect(t("a")).to eq "a"
      end

      it "returns empty string when given nil" do
        expect(t(nil)).to eq ""
      end

      it "converts single items to string" do
        expect(t(:c)).to eq "c"
      end
    end

    describe "l" do
      it "joins items with ', '" do
        expect(l(%w[a b c])).to eq "a, b, c"
      end
      it "converts inputs to strings" do
        expect(l(["a", "b", :c])).to eq "a, b, c"
      end
      it "removes nils" do
        expect(l(["a", nil, "b", :c])).to eq "a, b, c"
      end
      it "accepts single item" do
        expect(l("a")).to eq "a"
      end

      it "returns empty string when given nil" do
        expect(l(nil)).to eq ""
      end

      it "converts single items to string" do
        expect(l(:c)).to eq "c"
      end
    end

    describe "j" do
      it "converts input to JSON" do
        expect(j({ myObj: "data" })).to eq '{"myObj":"data"}'
      end
    end

    describe "s" do
      it "converts input to string without quotes"
      it "escapes double quotes"
      it "escapes single quotes"
    end
  end
end
