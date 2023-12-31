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

task default: %i[spec yard rubocop]
