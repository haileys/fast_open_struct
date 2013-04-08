require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = Dir["test/*.rb"]
end

task :default => :test

require 'rake/extensiontask'

Rake::ExtensionTask.new('fast_open_struct')
