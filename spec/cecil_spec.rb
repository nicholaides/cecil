RSpec.describe Cecil do
  it "has a version number" do
    expect(Cecil::VERSION).not_to be nil
  end

  require "stringio"

  describe ".call" do
    it "writes the code to an IO object" do
      buffer = StringIO.new

      Cecil::Code.call buffer do
        `echo NO`
      end

      expect(buffer.string).to eq "echo NO\n"
    end

    it "writes the code to a string" do
      buffer = ""

      Cecil::Code.call buffer do
        `echo NO`
      end

      expect(buffer).to eq "echo NO\n"
    end

    it "returns the given buffer/io/string" do
      expect(Cecil::Code.call("") do
        `echo NO`
      end).to eq "echo NO\n"
    end

    it "defaults to writing to stdout"
  end

  describe ".generate_string" do
    it "returns the generated code" do
      expect(Cecil::Code.generate_string do
        `echo NO`
      end).to eq "echo NO\n"
    end
  end

  def blank?(str) = str =~ /^\s*$/

  describe "outputting code" do
    def expect_code(...) = expect(code(...))
    def code(...) = Cecil::Code.generate_string(...)

    it "outputs code" do
      expect_code do
        `echo NO`
      end.to eq "echo NO\n"
    end

    it "outputs multiple lines" do
      expect_code do
        `line 1`
        `line 2`
      end.to eq <<~CODE
        line 1
        line 2
      CODE
    end

    describe "placeholders" do
      it "replaces positional placeholders" do
        expect_code do
          `line { $code } [ $another ]`["my code", "more code"]
        end.to eq <<~CODE
          line { my code } [ more code ]
        CODE
      end

      it "replaces named placeholders" do
        expect_code do
          `line { $code } [ $another ]`[code: "my code", another: "more code"]
        end.to eq <<~CODE
          line { my code } [ more code ]
        CODE
      end

      it "replaces positional placeholder values when there is one placeholder repeated" do
        expect_code do
          `line { $code } [ $code ] / $code /`["my code"]
        end.to eq <<~CODE
          line { my code } [ my code ] / my code /
        CODE
      end

      it "replaces positional placeholder values when there are multiple placeholders with the same name" do
        expect_code do
          `line { $code } [ $another ] / $code /`["my code", "more code"]
        end.to eq <<~CODE
          line { my code } [ more code ] / my code /
        CODE
      end

      it "replaces named placeholder values when there are multiple placeholders with the same name" do
        expect_code do
          `line { $code } [ $another ] / $code /`[code: "my code", another: "more code"]
        end.to eq <<~CODE
          line { my code } [ more code ] / my code /
        CODE
      end

      it "errors on positional and named placeholders" do
        expect do
          code do
            `line { $code } [ $another ]`["my code", another: "more code"]
          end
        end.to raise_error(/expects/i)
      end

      it "errors on unmatched placeholders given positional arguments" do
        expect do
          code do
            `line { $code } [ $another ]`["my code"]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholders given keyword arguments " do
        expect do
          code do
            `line { $code } [ $another ]`[code: "my code"]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholder values given positional arguments" do
        expect do
          code do
            `line { $code }`["my code", "more"]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholder values given keyword arguments " do
        expect do
          code do
            `line { $code }`[code: "my code", more: "some extra"]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholder values given keyword arguments " do
        expect do
          code do
            `line { $code }`[wrong_name: "my code"]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholder values given keyword arguments " do
        expect do
          code do
            `line { $code }`[]
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors on unmatched placeholder values given keyword arguments " do
        expect do
          code do
            `line { $code }`
          end
        end.to raise_error(/mismatch/i)
      end

      it "can include numbers, letters, and underscores" do
        expect_code do
          `my $c_odE2 code`["special"]
        end.to eq <<~CODE
          my special code
        CODE
      end

      it "can put placeholders adjacent to each other" do
        expect_code do
          `my $p1$p2`["special", " code"]
        end.to eq <<~CODE
          my special code
        CODE
      end

      describe "placeholder delimiting pairs in order to use placeholder as a prefix" do
        it "works with positional arguments" do
          expect_code do
            `class ${p1}Factory`["Curly"]
            `class $(p1)Factory`["Paren"]
            `class $<p1>Factory`["Angle"]
            `class $[p1]Factory`["Square"]
            `class $p0${p1}$[p2]Factory`["Basic", "Curly", "Square"]
          end.to eq <<~CODE
            class CurlyFactory
            class ParenFactory
            class AngleFactory
            class SquareFactory
            class BasicCurlySquareFactory
          CODE
        end

        it "works with named arguments" do
          expect_code do
            `class ${p1}Factory`[p1: "Curly"]
            `class $(p1)Factory`[p1: "Paren"]
            `class $<p1>Factory`[p1: "Angle"]
            `class $[p1]Factory`[p1: "Square"]
            `class $p0${p1}$[p2]Factory`[p0: "Basic", p1: "Curly", p2: "Square"]
          end.to eq <<~CODE
            class CurlyFactory
            class ParenFactory
            class AngleFactory
            class SquareFactory
            class BasicCurlySquareFactory
          CODE
        end
      end
    end

    describe "blocks" do
      describe "ending pairs"
    end
    describe "reindenting multiline strings"
    describe "adding trailing newlines to multiline strings"
    describe "using heredocs"
  end
end
