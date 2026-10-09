# encoding: UTF-8

require 'rake'
require 'rspec/core/rake_task'
require 'dotenv'

Dotenv.load(File.expand_path('.env', __dir__))

namespace :db do
  desc 'Migrate the database to the latest schema version'
  task :migrate do
    abort 'DATABASE_URL is not configured. Add it to the project .env file.' if ENV['DATABASE_URL'].to_s.strip.empty?

    require_relative 'model/init'
    require_relative 'lib/coeval/create_schema'

    Coeval::CreateSchema.new($db).migrate!
  end
end

desc 'Run the full spec suite'
RSpec::Core::RakeTask.new(:test) do |task|
  task.pattern = 'spec/**/*_spec.rb'
end

task default: :test
