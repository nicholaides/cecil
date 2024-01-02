RSpec.describe Cecil::Code do
  require "stringio"

  describe ".generate" do
    it "defaults to writing to stdout" do
      expect do
        Cecil::Code.generate do
          `hello world`
        end
      end.to output("hello world\n").to_stdout
    end

    shared_examples "a code receiver" do
      it "writes the code to an IO object" do
        Cecil::Code.generate buffer do
          `hello world`
        end

        expect(buffer_contents).to eq "hello world\n"
      end

      it "returns the given string, not necessarily the buffer" do
        returned_value = Cecil::Code.generate("") do
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
      generated_string = Cecil::Code.generate_string do
        `hello world`
      end

      expect(generated_string).to eq "hello world\n"
    end

    it "does not output to stdout" do
      expect do
        Cecil::Code.generate_string do
          `hello world`
        end
      end.to_not output.to_stdout
    end
  end
end
