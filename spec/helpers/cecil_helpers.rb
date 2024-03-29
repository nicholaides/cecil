require "cecil"

module CecilHelpers
  def expect_code(...) = expect(code(...))
  def code(...) = Cecil::Code.generate_string(...)
end
