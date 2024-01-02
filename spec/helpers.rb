require "cecil"

module Helpers
  def expect_code(...) = expect(code(...))
  def code(...) = Cecil::Code.generate_string(...)

  def cecil(&block)
    @cecil_block = block
  end

  def eval_cecil_block = code(&@cecil_block)

  def outputs(...) = expect(eval_cecil_block).to eq(...)

  def raises(...) = expect { eval_cecil_block }.to raise_error(...)
end
