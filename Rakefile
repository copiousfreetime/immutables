# vim: syntax=ruby
require "bundler/setup"
load "tasks/this.rb"

This.name = "immutables"
This.author = "Jeremy Hinegardner"
This.email = "jeremy@copiousfreetime.org"
This.homepage = "http://github.com/copiousfreetime/#{This.name}"

This.ruby_gemspec do |spec|
  spec.signing_key = Gem.default_key_path
  spec.cert_chain = [Gem.default_cert_path]

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/copiousfreetime/#{This.name}/issues",
    "changelog_uri" => "https://github.com/copiousfreetime/#{This.name}/blob/master/HISTORY.md",
    "homepage_uri" => "https://github.com/copiousfreetime/#{This.name}",
    "source_code_uri" => "https://github.com/copiousfreetime/#{This.name}",
    "label" => "immutables",
    "rubygems_mfa_required" => "true"
  }

  spec.license = "ISC"
end

load "tasks/default.rake"
