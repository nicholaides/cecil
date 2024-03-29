require "cecil"

module CecilHelpers
  def expect_code(...) = expect(code(...))
  def code(...) = described_code_class.generate_string(...)

  def described_code_class = described_class < Cecil::Code ? described_class : Cecil::Code # rubocop:disable Style/MinMaxComparison
end
