require "stringio"

RSpec.describe Cecil::Code do
  describe ".generate" do
    it "defaults to writing to stdout" do
      expect do
        described_class.generate do
          `hello world`
        end
      end.to output("hello world\n").to_stdout
    end

    shared_examples "a code receiver" do
      it "writes the code to an IO object" do
        described_class.generate buffer do
          `hello world`
        end

        expect(buffer_contents).to eq "hello world\n"
      end

      it "returns the given string, not necessarily the buffer" do
        returned_value = described_class.generate("") do
          `hello world`
        end

        expect(returned_value).to eq "hello world\n"
      end
    end

    describe "an IO object" do
      let(:buffer) { StringIO.new }
      let(:buffer_contents) { buffer.string }

      it_behaves_like "a code receiver"
    end

    describe "String" do
      let(:buffer) { "" }
      let(:buffer_contents) { buffer }

      it_behaves_like "a code receiver"
    end

    describe "an object that responds to #<<" do
      let :buffer do
        buff = BasicObject.new
        def buff.<<(value) = @appended_value = value
        def buff.value = @appended_value
        buff
      end

      let(:buffer_contents) { buffer.value }

      it_behaves_like "a code receiver"
    end
  end

  describe ".generate_string" do
    it "returns the generated code" do
      generated_string = described_class.generate_string do
        `hello world`
      end

      expect(generated_string).to eq "hello world\n"
    end

    it "does not output to stdout" do
      expect do
        described_class.generate_string do
          `hello world`
        end
      end.to_not output.to_stdout
    end
  end

  describe "overriding instance methods to change behavior" do
    def self.def_syntax(&)
      let(:syntax) do
        Class.new(described_class, &)
      end
    end

    def expect_syntax(&) = expect(syntax.generate_string(&))
    def expect_syntax_block(&) = expect { syntax.generate_string(&) }

    describe ".indent_chars" do
      describe "overriding with another string" do
        def_syntax do
          def indent_chars = "~->"
        end

        it "uses the overriden string for indentation" do
          expect_syntax do
            `def fn():`[] do
              `if cond:`[] do
                `return value`
              end
            end
          end.to eq <<~CODE
            def fn():
            ~->if cond:
            ~->~->return value
          CODE
        end
      end
    end

    describe ".block_ending_pairs" do
      describe "adding pairs" do
        def_syntax do
          def block_ending_pairs = super.merge({ "do" => "end" })
        end

        it "uses the added pair" do
          expect_syntax do
            `loop do`[] do
              `continue`
            end
          end.to eq <<~CODE
            loop do
                continue
            end
          CODE
        end
      end

      describe "removing pairs" do
        def_syntax do
          def block_ending_pairs = super.except("{")
        end

        it "uses the added pair" do
          expect_syntax do
            `loop {`[] do
              `continue`
            end
          end.to eq <<~CODE
            loop {
                continue
          CODE
        end
      end

      describe "turning the feature off" do
        def_syntax do
          def block_ending_pairs = {}
        end

        it "uses the added pair" do
          expect_syntax do
            `loop {`[] do
              `continue(`[] do
                `rocking`
              end
            end
          end.to eq <<~CODE
            loop {
                continue(
                    rocking
          CODE
        end
      end
    end

    describe ".placeholder_delimiting_pairs" do
      describe "turning the feature off" do
        def_syntax do
          def placeholder_delimiting_pairs = Cecil::Code::PLACEHOLDER_NO_BRACKETS_PAIR
        end

        it "does not match delimeting brackets" do
          expect_syntax do
            `class $c extends ${my} $parent`[c: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends ${my} Papa
          CODE
        end
      end

      describe "adding pairs" do
        def_syntax do
          def placeholder_delimiting_pairs = super.merge({ "/" => "/" })
        end

        it "does not match delimeting brackets" do
          expect_syntax do
            `class $c extends $/parent/`[c: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends Papa
          CODE
        end
      end

      describe "removing pairs" do
        def_syntax do
          def placeholder_delimiting_pairs = super.except("{")
        end

        it "does not match removed delimeting brackets" do
          expect_syntax do
            `class $c extends ${my} $(parent)`[c: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends ${my} Papa
          CODE
        end
      end

      describe "requiring pairs" do
        def_syntax do
          def placeholder_delimiting_pairs = super.except("")
        end

        it "does not match placeholder without brackets" do
          expect_syntax do
            `class ${c} extends $my $(parent)`[c: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends $my Papa
          CODE
        end
      end
    end

    describe ".placeholder_ident_re" do
      describe "overriding" do
        def_syntax do
          def placeholder_ident_re = /[A-Z_]+/
        end

        it "only matches placeholders that match that ident regexp" do
          expect_syntax do
            `class $C extends $my $(PARENT)`[C: "Baby", PARENT: "Papa"]
          end.to eq <<~CODE
            class Baby extends $my Papa
          CODE
        end
      end
    end

    describe ".placeholder_start_re" do
      describe "changing the starting Regexp" do
        def_syntax do
          def placeholder_start_re = /~~/
        end

        it "only matches placeholders that match that ident regexp" do
          expect_syntax do
            `class ~~c extends ~my ~~(parent)`[c: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends ~my Papa
          CODE
        end
      end
      describe "turning off the starting Regexp" do
        def_syntax do
          def placeholder_start_re = //
          def placeholder_ident_re = /[A-Z_]+/
        end

        it "only matches placeholders that match that ident regexp" do
          expect_syntax do
            `class C extends $my (PARENT)`[C: "Baby", PARENT: "Papa"]
          end.to eq <<~CODE
            class Baby extends $my Papa
          CODE
        end
      end
    end

    describe ".placeholder_re" do
      describe "overriding" do
        def_syntax do
          # capitalized word
          def placeholder_re = /::(?<placeholder>[a-z]+);/
        end

        it "only matches placeholders that matche the regexp" do
          expect_syntax do
            `class ::class; extends $my ::parent;`[class: "Baby", parent: "Papa"]
          end.to eq <<~CODE
            class Baby extends $my Papa
          CODE
        end
      end
    end

    describe ".scan_for_placeholders" do
      it "returns an array of Placeholders" do
        template = "class $CLASS extends $PARENT export $CLASS"

        expect(described_class.new.scan_for_placeholders(template)).to eq [
          Cecil::Placeholder.new("CLASS", 6, 12),
          Cecil::Placeholder.new("PARENT", 21, 28),
          Cecil::Placeholder.new("CLASS", 36, 42)
        ]
      end

      describe "overriding" do
        def_syntax do
          def scan_for_placeholders(...) = super.each { _1.ident.upcase! }
        end

        it "capitalizes idents" do
          expect_syntax do
            `class $c extends $parent`[C: "Baby", PARENT: "Papa"]
          end.to eq <<~CODE
            class Baby extends Papa
          CODE
        end
      end
    end

    describe ".handle_ambiguous_indentation" do
      describe "defaults raising an error" do
        it "raises an error" do
          expect_syntax_block do
            `def my_func():
              pass`
          end.to raise_error(/ambiguous/i)
        end
      end

      describe "overrideing to raise an error" do
        def_syntax do
          def handle_ambiguous_indentation = Cecil::Indentation::Ambiguity.raise_error
        end

        it "raises an error" do
          expect_syntax_block do
            `def python_func():
              pass`
          end.to raise_error(/ambiguous/i)
        end
      end

      describe "overriding to adjust" do
        def_syntax do
          def handle_ambiguous_indentation = Cecil::Indentation::Ambiguity.adjust_by(2)
        end

        it "adjusts by 2 characters" do
          expect_syntax do
            `def python_func():
            pass`
          end.to eq <<~CODE
            def python_func():
              pass
          CODE
        end
      end

      describe "overriding to ignore" do
        def_syntax do
          def handle_ambiguous_indentation = Cecil::Indentation::Ambiguity.ignore
        end

        it "leaves the indentation level" do
          expect_syntax do
            `def ruby_method
            end`
          end.to eq <<~CODE
            def ruby_method
            end
          CODE
        end
      end
    end
  end
end
