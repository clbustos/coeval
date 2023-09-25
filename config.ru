# encoding: utf-8
#\ -w 

require 'sinatra'
require 'dotenv'
require 'rack/session/moneta'



Dotenv.load("./.env") if File.exist? "./env" and ENV['RACK_ENV']!="test"

session_key         = ENV['PRODUCTION_SESSION_KEY']        || '5ffabe6222cca909f814b2defa3ddf8cbee799697fc4d076ff1a33855eebdea799b33dd1fe5dde3efb9aea9d796a0a88325147078d8c4f5f3c16a7ae4d9e99a9'
session_domain      = ENV['PRODUCTION_SESSION_DOMAIN']     || 'localhost'
session_secret_key  = ENV['PRODUCTION_SESSION_SECRET_KEY'] || 'd80ed0b6ef9f8653aa8c6f1a8d43147aecddc325b40d8beefe57e8aa780e25914421077fe44706e212eb3e297c2a950ddebdc09614d5e32c980cfa773732ca0f'


#Sinatra::Application.default_options.merge!(
#  :run => false,
#  :env => :production
#)

disable :run
set :session_secret, "abf63db09a91000521d33b5a62256ade7c38b25c585e715747fedf37a0b237091a3978a58a0a51883a6a34777a9ac9f6d0a5719ff74b52df1f30f8830204e83b"
set :show_exceptions, true

if ENV['RACK_ENV'].to_sym == :production
  use Rack::Session::Moneta,
      key:            session_key,
      domain:         session_domain,
      path:           '/',
      expire_after:   7*24*60*60, # one week
      secret:         session_secret_key,

      store:          Moneta.new(:LRUHash, {
          url:            session_domain,
          expires:        true,
          threadsafe:     true
      })
else
  use Rack::Session::Moneta,
      key:            'domain.name',
      domain:         '*',
      path:           '/',
      expire_after:   30*24*60*60, # one month
      secret:         ENV['DEV_SESSION_SECRET_KEY'],

      store:          Moneta.new(:LRUHash, {
          url:            'localhost',
          expires:        true,
          threadsafe:     true
      })
end
#require 'rack-mini-profiler'

use Rack::ShowExceptions
#use Rack::MiniProfiler

#if File.exist?("config/installed")
  require_relative 'app.rb'
  run Sinatra::Application
#else
#  require_relative 'installer.rb'
#  run Buhos::Installer
#end
