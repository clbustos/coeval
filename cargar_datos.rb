# encoding: UTF-8

require 'dotenv'

$test_mode = ENV['RACK_ENV'].to_s == 'test'
Dotenv.load('./.env') unless $test_mode

require_relative 'model/init'
require_relative 'lib/coeval/create_schema'

schema = Coeval::CreateSchema.new($db)
schema.migrate!
schema.seed_base_data!
schema.seed_demo_data!(strict: false)
