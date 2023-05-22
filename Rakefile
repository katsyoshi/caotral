# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "steep"
require "steep/cli"

task default: %i[test]

namespace :steep do
  desc "steep type check"
  task :check do
    steep_cmd_task(["check"])
  end
end

Rake::TestTask.new do |t|
  t.test_files = FileList['test/test*.rb']
end

def steep_cmd_task(argv) = Steep::CLI.new(argv: argv, stdout: STDOUT, stdin: STDIN, stderr: STDERR).run
