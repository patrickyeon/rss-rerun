require "bundler/gem_tasks"
require "rake"
require "rake/testtask"

# TODO clean out temp files before running tests

Rake::TestTask.new do |t|
    t.test_files = Rake::FileList['test/test_*.rb']
    t.verbose = true
end

task :default => :test
