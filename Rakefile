# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "rake/clean"
CLEAN.include ".yardoc/"

require "yard"
YARD::Rake::YardocTask.new do |t|
  t.options = %w[--no-cache --fail-on-warning]
end

directory ".yard"
CLEAN.include ".yard/"

def normalize_yard_ref(str)
  if str.start_with?("Cecil::")
    str
  else
    "Cecil::#{str}"
  end
end

def convert_markdown_yardoc_links_to_yardoc(str)
  str.gsub(/\[(.+)\]\[\{([^\}\]]+)\}\]/) { "{#{normalize_yard_ref(Regexp.last_match(2))} #{Regexp.last_match(1)}}" }
end

file ".yard/README.md" => ["README.md", ".yard"] do |t|
  File.write t.name, convert_markdown_yardoc_links_to_yardoc(File.read("README.md"))
end
task yard: ".yard/README.md"

task :ensure_yard_readme_is_up_to_date do
  if File.read(".yard/README.md") != convert_markdown_yardoc_links_to_yardoc(File.read("README.md"))
    raise ".yard/README.md is not up-to-date. Run `rake` before committing."
  end
end

task default: %i[spec yard rubocop]
