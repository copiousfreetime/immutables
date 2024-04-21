require 'simplecov'

unless ENV['NO_COVERAGE']
  SimpleCov.start do
    add_filter %r{(^test/)}
    enable_coverage :branch
    minimum_coverage_by_file line: 95, branch: 95
  end
end

Bundler.require :test

require 'minitest/autorun'
require 'minitest/pride'
require 'immutables'

TEST_ROOT = Pathname.new( __dir__ ).realpath.freeze
