require "cecil/lang/typescript"

RSpec.describe Cecil::Lang::TypeScript do # rubocop:disable RSpec/FilePath,RSpec/SpecFilePathFormat
  it "indents with 2 spaces" do
    expect_code do
      `function $fn() {`["fibonacci"] do
        `recurse()`
      end
    end.to eq <<~CODE
      function fibonacci() {
        recurse()
      }
    CODE
  end

  it "closes curly braces" do
    expect_code do
      `function $fn() {`["fibonacci"] do
        `do_stuff()`
      end
    end.to eq <<~CODE
      function fibonacci() {
        do_stuff()
      }
    CODE
  end

  it "closes parens" do
    expect_code do
      `myFunc(`[] do
        `value`
      end
    end.to eq <<~CODE
      myFunc(
        value
      )
    CODE
  end

  it "closes square brackets" do
    expect_code do
      `values = [`[] do
        `v1,`
        `v2`
      end
    end.to eq <<~CODE
      values = [
        v1,
        v2
      ]
    CODE
  end

  it "closes multi-line comments" do
    expect_code do
      `/*`[] do
        `comments`
      end
    end.to eq <<~CODE
      /*
        comments
      */
    CODE
  end

  it "does not indent ambigous lines" do
    expect_code do
      `function () {
      }`
    end.to eq <<~CODE
      function () {
      }
    CODE
  end

  describe Cecil::Lang::TypeScript::Helpers do
    include described_class

    describe "#t" do
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

    describe "#l" do
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

    describe "#j" do
      it "converts input to JSON" do
        expect(j({ myObj: "data" })).to eq '{"myObj":"data"}'
      end
    end

    describe "#s" do
      it "converts input to string without quotes" do
        expect(s("hello world")).to eq "hello world"
      end

      it "escapes double quotes" do
        expect(s('hello "world"')).to eq 'hello \\"world\\"'
      end

      it "escapes single quotes" do
        expect(s("hello 'world'")).to eq "hello \\'world\\'"
      end

      it "escapes backticks" do
        expect(s("hello `world`")).to eq "hello \\`world\\`"
      end

      it "dollar signs" do
        expect(s("hello ${world}")).to eq "hello \\${world}"
      end
    end
  end
end
