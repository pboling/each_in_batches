require "bundler/gem_tasks"

begin
  require "rspec/core/rake_task"
  desc 'Run specs'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.ruby_opts = '-w'
  end
  task :default => :spec
rescue LoadError
end
