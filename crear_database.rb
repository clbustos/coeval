# encoding: UTF-8

require 'dotenv'

$test_mode = ENV['RACK_ENV'].to_s == 'test'
Dotenv.load('./.env') unless $test_mode

require_relative 'model/init'
require_relative 'lib/coeval/create_schema'

Coeval::CreateSchema.new($db).migrate!
