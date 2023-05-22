# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "steep"
require "steep/cli"

task default: %i[test]

Rake::TestTask.new do |t|
  t.test_files = FileList['test/test*.rb']
end

namespace :steep do
  desc "steep type check"
  task :check do |_t, options|
    steep_cmd_task(:check, *options.to_a)
  end

  desc "steep type annotations"
  task :annotations do |_t, options|
    steep_cmd_task(:annotations, *options.to_a)
  end
end

def steep_cmd_task(*commands) = Steep::CLI.new(argv: commands, stdout: STDOUT, stdin: STDIN, stderr: STDERR).run
