require 'rspec/core'
require 'hatchet'
require 'fileutils'
require 'hatchet'
require 'rspec/retry'
require 'date'

ENV['RACK_ENV'] = 'test'

RSpec.configure do |config|
  config.filter_run focused: true unless ENV['CI']
  config.run_all_when_everything_filtered = true
  config.alias_example_to :fit, focused: true
  config.full_backtrace      = true
  config.verbose_retry       = true # show retry status in spec process
  config.default_retry_count = 2 if ENV['CI'] # retry all tests that fail again

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  #config.mock_with :none
end

def git_repo
  "https://github.com/heroku/heroku-buildpack-clojure.git"
end

def add_database(app, heroku)
  Hatchet::RETRIES.times.retry do
    heroku.post_addon(app.name, 'heroku-postgresql:hobby-dev')
    _, value = heroku.get_config_vars(app.name).body.detect {|key, value| key.match(/HEROKU_POSTGRESQL_[A-Z]+_URL/) }
    heroku.put_config_vars(app.name, 'DATABASE_URL' => value)
  end
end

def successful_body(app, options = {})
  retry_limit = options[:retry_limit] || 50
  path = options[:path] ? "/#{options[:path]}" : ''
  Excon.get("http://#{app.name}.herokuapp.com#{path}", :idempotent => true, :expects => 200, :retry_limit => retry_limit).body
end

def create_file_with_size_in(size, dir)
  name = File.join(dir, SecureRandom.hex(16))
  File.open(name, 'w') {|f| f.print([ 1 ].pack("C") * size) }
  Pathname.new name
end

def set_java_version(d, v)
  Dir.chdir(d) do
    File.open('system.properties', 'w') do |f|
      f.puts "java.runtime.version=#{v}"
    end
    `git commit -am "setting jdk version"`
  end
end
