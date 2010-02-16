#!/usr/bin/env ruby
require 'logger'
require 'vendor/csp/lib/csp'
$LOAD_PATH.unshift ::File.expand_path(::File.dirname(__FILE__) + '/lib')
require 'resque/server'

# Set the RESQUECONFIG env variable if you've a `resque.rb` or similar
# config file you want loaded on boot.
if ENV['RESQUECONFIG'] && ::File.exists?(::File.expand_path(ENV['RESQUECONFIG']))
  load ::File.expand_path(ENV['RESQUECONFIG'])
end

use Rack::ShowExceptions
require 'test-failures/fail'

# use Jabs::Rack::Static, :urls => '/jabs', :root => Pathname.new(__FILE__).dirname.expand_path+'lib/resque/server'

class EchoSession < CSP::Session
  def receive_data(data)
    self.class.broadcast(data)
  end
  
  def self.broadcast(data)    
    @@all_sessions.each do |id, session|
      session.send_data(data)
    end
  end
end
csp_app = CSP::Application.new(EchoSession)

run Rack::URLMap.new  \
  "/" => Resque::Server.new,
  "/csp" => csp_app.mountable
