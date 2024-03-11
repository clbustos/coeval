source 'https://rubygems.org'
gem 'rake'
gem 'rack'
gem 'mail'
gem "sinatra",  '>=2.0.1'
gem "sequel"
gem "mysql2"
gem "json"
gem "haml"
gem "rspec"
gem "rack-test"
gem "unicode"
gem 'serrano'
gem 'dotenv'
gem 'nokogiri', :force_ruby_platform=> true
gem 'moneta'
gem 'simple_xlsx_reader'
gem "i18n"
gem "sqlite3", :force_ruby_platform=>:true
gem 'mimemagic'
gem "certified", :platforms => :mingw
gem 'rubyXL'
gem 'caxlsx'

#gem 'rubyXL'
#gem 'ai4r'

#gem 'nbayes'
#gem 'classifier-reborn'

group :production do
  gem "puma", :platforms => :mingw
  gem "thin", :force_ruby_platform=>true

end
group :development do
  gem 'pkgr'
  gem 'yard', :require => false
  gem 'yard-sinatra', :require => false
  gem 'pry'
  gem 'mutant'
  gem 'mutant-rspec'
  gem "sassc"
end

group :test do
  gem 'simplecov', :require => false
  gem 'test-prof', :require => false
end

