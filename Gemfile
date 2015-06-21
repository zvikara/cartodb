source 'http://rubygems.org'

gem 'rails',                   '3.2.22'

gem 'rake',                    '10.4.2'
gem 'pg',                      '0.18.2'
gem 'sequel',                  '3.48.0'
gem 'sequel_pg',               '1.6.12', require: 'sequel'

gem 'activerecord-postgresql-adapter'
gem 'activerecord-postgres-array'

gem 'vizzuality-sequel-rails', '0.3.7', git: 'https://github.com/Vizzuality/sequel-rails.git'

gem 'rails_warden',            '0.5.8' # Auth via the Warden Rack framework
gem 'oauth',                   '0.4.7'
gem 'oauth-plugin',            '0.5.1'

gem 'redis',                   '3.2.1'
gem 'hiredis',                 '0.6.0'
gem 'nokogiri',                '~> 1.6.6.2'
gem 'statsd-client',           '0.0.8', require: 'statsd'
gem 'aws-sdk',                 '2.1.1'
gem 'ruby-prof',               '0.15.8'
gem 'request_store',           '1.1.0'

# It's used in the dataimport and arcgis.
# It's a replacement for the ruby uri that it's supposed to perform better parsing of a URI
gem 'addressable',             '2.3.8', require: 'addressable/uri'

gem 'ejs',                     '~> 1.1.1'
gem 'execjs',                  '2.5.2' # Required by ejs
gem 'therubyracer',            '0.12.2' # Required by ejs


group :production, :staging do
  gem 'unicorn',               '4.8.2'
  gem 'raindrops',             '0.12.0'
end

group :assets do
  gem "compass",               "1.0.3"
end

# Importer & sync tables
gem 'roo',                     '2.0.1'
gem 'state_machine',           '1.2.0'
gem 'typhoeus',                '0.7.2'
gem 'charlock_holmes',         '0.7.3'
gem 'dbf',                     '2.0.10'
gem 'faraday',                 '~> 0.9.1'
gem 'retriable',               '~> 1.4.1'
gem 'google-api-client',       '0.8.6'
gem 'dropbox-sdk',             '1.6.4'
gem 'instagram',               '1.1.5'
gem 'gibbon',                  '1.1.5'

# Geocoder (synchronizer doesn't needs it anymore)
gem 'eventmachine',            '1.0.7'
gem 'em-pg-client',            '0.3.4'

# Service components (/services)
gem 'virtus',                   '1.0.5'
gem 'aequitas',                 '0.0.2'
gem 'uuidtools',                '2.1.5'

# Markdown
gem 'redcarpet', '3.3.1'

# TODO we should be able to remove this using the new
#      Rails routes DSL
gem 'bartt-ssl_requirement',   '~>1.4.2', require: 'ssl_requirement'

# TODO Production gems, put them in :production group
gem 'mixpanel',              '4.1.1'
gem 'rollbar',               '1.5.3'
gem 'resque',                '1.25.2'
gem 'resque-metrics',        '0.1.1'

group :test do
  gem 'db-query-matchers',     '0.4.0'
  gem 'rack-test',             '0.6.3',  require: 'rack/test'
  gem 'factory_girl_rails',    '~> 4.5.0'
  gem 'selenium-webdriver',    '>= 2.46.2'
  gem 'capybara',              '2.4.4'
  gem 'delorean',              '2.1.0'
  gem 'webrick',               '1.3.1'
  gem 'mocha',                 '1.1.0'
  gem 'ci_reporter',           '2.0.0'
  gem 'rspec-rails',           '3.3.2'
  gem 'poltergeist',           '>= 1.6.0'
  gem 'activerecord-nulldb-adapter', '0.3.1'
end

group :development, :test do
  gem 'rb-readline',           '0.5.3'
  gem 'debugger',              '1.6.8'
  gem 'rack',                  '1.6.4'

  # Server
  gem 'thin', require: false
end

# Load optional engines
# TODO activate when CartoDB plugins are finally included
# Dir['engines' + '/*/*.gemspec'].each do |gemspec_file|
#   dir_name = File.dirname(gemspec_file)
#   gem_name = File.basename(gemspec_file, File.extname(gemspec_file))
#   gem gem_name, :path => dir_name, :require => false
# end
