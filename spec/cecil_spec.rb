RSpec.describe Cecil do
  it "has a version number" do
    expect(Cecil::VERSION).not_to be nil
  end

  describe "nesting generation calls" do
    it "can generate in sequence" do
      inner = Cecil::Code.generate_string do
        `inner {`[] do
          `content`
        end
      end

      expect(inner).to eq <<~CODE
        inner {
            content
        }
      CODE

      outer = Cecil::Code.generate_string do
        `start outer`

        `end outer`
      end

      expect(outer).to eq <<~CODE
        start outer
        end outer
      CODE
    end

    it "can generate while another is generating" do
      inner = nil
      outer = Cecil::Code.generate_string do
        `start outer`
        inner = Cecil::Code.generate_string do
          `inner {`[] do
            `content`
          end
        end
        `end outer`
      end

      expect(inner).to eq <<~CODE
        inner {
            content
        }
      CODE

      expect(outer).to eq <<~CODE
        start outer
        end outer
      CODE
    end
  end

  it "can generate and include the contents of another" do
    expect(
      Cecil::Code.generate_string do
        `start outer`
        src(
          Cecil::Code.generate_string do
            `inner {`[] do
              `content`
            end
          end
        )
        `end outer`
      end
    ).to eq <<~CODE
      start outer
      inner {
          content
      }
      end outer
    CODE
  end

  it "indents correctly when nesting generation" do
    expect(
      Cecil::Code.generate_string do
        `outer (`[] do
          src(
            Cecil::Code.generate_string do
              `inner {`[] do
                `content`
              end
            end
          )
        end
      end
    ).to eq <<~CODE
      outer (
          inner {
              content
          }
      )
    CODE
  end

  def blank?(str) = str =~ /^\s*$/

  describe "outputting code" do
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
        cecil do
          `line { $code } [ $another ]`["my code", another: "more code"]
        end

        raises(/expects/i)
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

      it "errors immediately when called if arguments are incorrect" do
        found_error = nil

        begin
          code do
            `line { $code }`[]
          rescue StandardError => e
            found_error = e
          end
        rescue StandardError
          nil
        end

        expect(found_error.message).to match(/mismatch/i)
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
      describe "ending pairs" do
        it "closes opened brackets" do
          expect_code do
            `outer {`[] do
              `inner`
            end
          end.to eq <<~CODE
            outer {
                inner
            }
          CODE
        end

        it "closes opened brackets even with no children" do
          expect_code do
            `outer {`[] do
              # noop
            end
          end.to eq <<~CODE
            outer {
            }
          CODE
        end
      end
      describe "indentation" do
        it "indents blocks" do
          cecil do
            `start outer`
            `inner {`[] do
              `content`
            end
            `end outer`
          end

          outputs <<~CODE
            start outer
            inner {
                content
            }
            end outer
          CODE
        end
      end
    end

    describe "reindenting multiline strings"
    describe "adding trailing newlines to multiline strings"
    describe "using heredocs"

    describe "deferred code blocks" do
      it "defers code blocks for evaluation" do
        expect_code do
          items = []
          defer do
            `export { $items }`[items.join(", ")]
          end
          %w[A B C].each do |klass|
            items << klass
            `class $Class`[klass]
          end
        end.to eq <<~CODE
          export { A, B, C }
          class A
          class B
          class C
        CODE
      end

      it "defers code blocks for evaluation and keep proper indentation level" do
        expect_code do
          items = []
          `export {`[] do
            defer do
              `$items`[items.join(", ")]
            end
          end

          %w[A B C].each do |klass|
            items << klass
            `class $Class`[klass]
          end
        end.to eq <<~CODE
          export {
              A, B, C
          }
          class A
          class B
          class C
        CODE
      end
    end

    describe ".content_for" do
      it "outputs later when called" do
        expect_code do
          %w[A B C].each do |klass|
            `class $Class {}`[klass]

            content_for :exports do
              `export $Class`[klass]
            end
          end
          content_for :exports
        end.to eq <<~CODE
          class A {}
          class B {}
          class C {}
          export A
          export B
          export C
        CODE
      end

      it "indents content to level of location in document" do
        expect_code do
          %w[A B C].each do |klass|
            `class $Class {}`[klass]

            content_for :exports do
              `-> $Class`[klass]
            end
          end

          `exporting {`[] do
            content_for :exports
          end
        end.to eq <<~CODE
          class A {}
          class B {}
          class C {}
          exporting {
              -> A
              -> B
              -> C
          }
        CODE
      end

      it "outputs above" do
        expect_code do
          `code`
          defer do
            content_for :exports
          end

          %w[A B C].each do |klass|
            `class $Class {}`[klass]

            content_for :exports do
              `export $Class`[klass]
            end
          end
        end.to eq <<~CODE
          code
          export A
          export B
          export C
          class A {}
          class B {}
          class C {}
        CODE
      end

      it "outputs above and indents content to level of location in document" do
        expect_code do
          `exporting {`[] do
            content_for :exports
          end

          %w[A B C].each do |klass|
            `class $Class {}`[klass]

            content_for :exports do
              `-> $Class`[klass]
            end
          end
        end.to eq <<~CODE
          exporting {
              -> A
              -> B
              -> C
          }
          class A {}
          class B {}
          class C {}
        CODE
      end
    end

    describe "Node#<<" do
      it "can append Code to the generated code block" do
        expect_code do
          `func {`[] do
            `do stuff`
          end << ` -> call`
        end.to eq <<~CODE
          func {
              do stuff
          } -> call
        CODE
      end

      it "can append string to the generated code block" do
        expect_code do
          `func {`[] do
            `do stuff`
          end << " -> call"
        end.to eq <<~CODE
          func {
              do stuff
          } -> call
        CODE
      end

      it "can append a few things to the generated code block" do
        expect_code do
          `func {`[] do
            `do stuff`
          end << "1" << `2` << "3" << `4`
        end.to eq <<~CODE
          func {
              do stuff
          }1234
        CODE
      end

      it "can append a string to a literal node" do
        expect_code do
          `literal` << "String"
        end.to eq <<~CODE
          literalString
        CODE
      end

      it "errors when appending a string to a template node" do
        expect do
          code do
            `template $name ` << "String"
          end
        end.to raise_error(/mismatch/i)
      end

      it "errors when appending a literal node to a template node" do
        expect do
          code do
            `template $name ` << `literal`
          end
        end.to raise_error(/mismatch/i)
      end

      it "can append a string to a deferred node" do
        expect_code do
          defer do
            `literal`
          end << "String"
        end.to eq <<~CODE
          literalString
        CODE
      end

      it "can append a literal node to a deferred node" do
        expect_code do
          defer do
            `literal`
          end << `AnotherLiteral`
        end.to eq <<~CODE
          literalAnotherLiteral
        CODE
      end

      it "cannot append when storing in content_for" do
        expect do
          code do
            content_for(:imports) do
              `literal`
            end << "String"

            content_for :imports
          end
        end.to raise_error(/undefined method `<<' for nil:NilClass/)
      end

      it "can append to a content_for node" do
        expect_code do
          content_for(:imports) do
            `literal`
          end

          content_for(:imports) << "String"
        end.to eq <<~CODE
          literalString
        CODE
      end

      it "can append a template node" do
        expect_code do
          `literal` << `Template $name`["Bob"]
        end.to eq <<~CODE
          literalTemplate Bob
        CODE
      end

      it "can append a deferred node" do
        expect_code do
          `literal` << defer do
            `DeferredLiteral`
          end
        end.to eq <<~CODE
          literalDeferredLiteral
        CODE
      end

      it "can append a content_for node" do
        expect_code do
          content_for(:imports) do
            `literal`
          end

          `imports ` << content_for(:imports)
        end.to eq <<~CODE
          imports literal
        CODE
      end
    end
  end

  describe "customizing configuration" do
    it "works" do
      require "cecil/lang/typescript"
      expect(
        Cecil::Lang::TypeScript.generate_string do
          `function($args) {`[l %w[a b c]] do
            `doStuff()`
          end
        end
      ).to eq <<~CODE
        function(a, b, c) {
          doStuff()
        }
      CODE
    end
  end

  describe "ambiguous indentation" do
    it "errors when backticks are used with ambiguous indentation" do
      # because, which should the be?
      # ```
      # def fn():
      #   pass
      # ```
      # or
      # ```
      # def fn():
      # pass
      # ```
      expect do
        code do
          `def fn():
            pass`
        end
      end.to raise_error(/ambiguous/i)
    end
  end
end

def object_method = "OBJECT METHOD"

RSpec.describe Cecil do
  describe "block scope" do
    it "has access to methods defined in the global scope" do
      expect(code do
        src object_method
      end.strip).to eq object_method
    end

    def receiver_method = "RECEIVER METHOD"

    it "has access to methods defined in the block's scope" do
      expect(code do
        src receiver_method
      end.strip).to eq receiver_method
    end
  end
end
