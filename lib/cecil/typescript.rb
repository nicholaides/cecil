require_relative "../cecil"

module Cecil
  require "json"
  class TypeScript < Code
    def indent_chars = "  "

    helpers do
      def t(items) = Array(items).join(" | ")
      def l(items) = Array(items).join(", ")
      def s(item) = item.to_s.to_json[1...-1]
      def j(item) = item.to_json
    end
  end
end
