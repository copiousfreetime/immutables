# vim: syntax=ruby
require "rake/clean"
require "digest"
require "debug"
require "standard/rake"
require "reek/rake/task"

#------------------------------------------------------------------------------
# Minitest - standard TestTask
#------------------------------------------------------------------------------
begin
  require "minitest/test_task"
  Minitest::TestTask.create(:test) do |t|
    t.libs << "lib"
    t.libs << "spec"
    t.libs << "test"
    t.warning = true
    t.test_globs = "{test,spec}/**/{test_*,*_spec}.rb"
  end

  task :test_requirements
  task test: :test_requirements
  task default: :test
rescue LoadError
  This.task_warning("test")
end

#------------------------------------------------------------------------------
# RDoc - standard rdoc rake task, although we must make sure to use a more
#        recent version of rdoc since it is the one that has 'tomdoc' markup
#------------------------------------------------------------------------------
begin
  gem "rdoc" # otherwise we get the wrong task from stdlib
  require "rdoc/task"
  RDoc::Task.new do |t|
    t.markup = "tomdoc"
    t.rdoc_dir = "doc"
    t.main = "README.md"
    t.title = "#{This.name} #{This.version}"
    t.rdoc_files.include(FileList["*.{rdoc,md,txt}"], FileList["ext/**/*.c"],
      FileList["lib/**/*.rb"])
  end
rescue StandardError, LoadError
  This.task_warning("rdoc")
end

#------------------------------------------------------------------------------
# Coverage - optional code coverage, rcov for 1.8 and simplecov for 1.9, so
#            for the moment only rcov is listed.
#------------------------------------------------------------------------------
begin
  require "simplecov"
  desc "Run tests with code coverage"
  task :coverage do
    ENV["COVERAGE"] = "true"
    Rake::Task[:test].execute
  end
  CLOBBER << "coverage" if File.directory?("coverage")
rescue LoadError
  This.task_warning("simplecov")
end

#------------------------------------------------------------------------------
# Manifest - We want an explicit list of thos files that are to be packaged in
#            the gem. Most of this is from Hoe.
#------------------------------------------------------------------------------
namespace "manifest" do
  desc "Check the manifest"
  task check: :clean do
    files = FileList["**/*", ".*"].exclude(This.exclude_from_manifest).to_a.sort
    files = files.select { |f| File.file?(f) }

    tmp = "Manifest.tmp"
    File.open(tmp, "w") do |f|
      f.puts files.join("\n")
    end

    begin
      sh "diff -du Manifest.txt #{tmp}"
    ensure
      rm tmp
    end
    puts "Manifest looks good"
  end

  desc "Generate the manifest"
  task generate: :clean do
    files = `git ls-files`.split("\n").sort
    files.reject! { |f| f =~ This.exclude_from_manifest }
    File.open("Manifest.txt", "w") do |f|
      f.puts files.join("\n")
    end
  end
end

#------------------------------------------------------------------------------
# Fixme - look for fixmes and report them
#------------------------------------------------------------------------------
namespace :fixme do
  task default: "manifest:check" do
    This.manifest.each do |file|
      next if file == __FILE__
      next unless %r{(txt|rb|md|rdoc|css|html|xml|css)\Z}.match?(file)
      puts "FIXME: Rename #{file}" if /fixme/i.match?(file)
      IO.readlines(file).each_with_index do |line, idx|
        prefix = "FIXME: #{file}:#{idx + 1}".ljust(42)
        puts "#{prefix} => #{line.strip}" if /fixme/i.match?(line)
      end
    end
  end

  def fixme_project_root
    This.project_path("../fixme")
  end

  def fixme_project_path(subtree)
    fixme_project_root.join(subtree)
  end

  def local_fixme_files
    local_files = This.manifest.select { |p| p =~ %r{^tasks/} }
    local_files.concat(Dir.glob(".semaphore/*"))
  end

  def outdated_fixme_files
    local_fixme_files.select do |local|
      upstream = fixme_project_path(local)
      if upstream.exist?
        if File.exist?(local)
          (Digest::SHA256.file(local) != Digest::SHA256.file(upstream))
        else
          true
        end
      end
    end
  end

  def fixme_up_to_date?
    outdated_fixme_files.empty?
  end

  desc "See if the fixme tools are outdated"
  task :outdated do
    if fixme_up_to_date?
      puts "Fixme files are up to date."
    else
      outdated_fixme_files.each do |f|
        puts "#{f} is outdated"
      end
    end
  end

  desc "Update outdated fixme files"
  task :update do
    if fixme_up_to_date?
      puts "Fixme files are already up to date."
    else
      puts "Updating fixme files:"
      outdated_fixme_files.each do |local|
        upstream = fixme_project_path(local)
        puts "  * #{local}"
        FileUtils.cp(upstream, local)
      end
      puts "Use your git commands as appropriate."
    end
  end
end
desc "Look for fixmes and report them"
task fixme: "fixme:default"

#------------------------------------------------------------------------------
# Gem Specification
#------------------------------------------------------------------------------
# Really this is only here to support those who use bundler
desc "Build the #{This.name}.gemspec file"
task :gemspec do
  File.open(This.gemspec_file, "wb+") do |f|
    f.puts "# DO NOT EDIT - This file is automatically generated"
    f.puts "# Make changes to Manifest.txt and/or Rakefile and regenerate"
    f.write This.platform_gemspec.to_ruby
  end
end

# .rbc files from ruby 2.0
CLOBBER << "**/*.rbc"

# The standard gem packaging task, everyone has it.
require "rubygems/package_task"
::Gem::PackageTask.new(This.platform_gemspec) do
  # nothing
end

#------------------------------------------------------------------------------
# Release - the steps we go through to do a final release, this is pulled from
#           a compbination of mojombo's rakegem, hoe and hoe-git
#
# 1) make sure we are on the main branch
# 2) make sure there are no uncommitted items
# 3) check the manifest and make sure all looks good
# 4) build the gem
# 5) do an empty commit to have the commit message of the version
# 6) tag that commit as the version
# 7) push main
# 8) push the tag
# 7) pus the gem
#------------------------------------------------------------------------------
task :release_check do
  unless /^\* main/.match?(`git branch`)
    abort "You must be on the main branch to release!"
  end
  unless /^nothing to commit/m.match?(`git status`)
    abort "Nope, sorry, you have unfinished business"
  end
end

desc "Create tag v#{This.version}, build and push #{This.platform_gemspec.full_name} to rubygems.org"
task release: [:release_check, "manifest:check", :gem] do
  sh "git commit --allow-empty -a -m 'Release #{This.version}'"
  sh "git tag -a -m 'v#{This.version}' v#{This.version}"
  sh "git push origin main"
  sh "git push origin v#{This.version}"
  sh "gem push pkg/#{This.platform_gemspec.full_name}.gem"
end
