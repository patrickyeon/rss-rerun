require "bundler/gem_tasks"
require "rake"
require "rake/testtask"

# TODO clean out temp files before running tests
directory 'tmp/store'

Rake::TestTask.new do |t|
    if Dir.entries('tmp/store').length > 2
        # hacky way to clean out any files if they exist
        sh %{rm -r tmp/store/*}
    end
    t.test_files = Rake::FileList['test/test_*.rb']
    t.verbose = true
end

task :test_nos3 do
    ENV['RSS_RERUN_STORE'] = 'disk'
    Rake::Task[:test].invoke
end

task :test_s3 do
    ENV['RSS_RERUN_STORE'] = 'S3'
    Rake::Task[:test].invoke
end

task :test_all do
    Rake::Task[:test_nos3].invoke
    # HACK the following breaks through layers of abstraction
    Rake::Task[:test].reenable
    Rake::Task[:test_s3].invoke
end

task :default => :test_nos3
