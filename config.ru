#!/usr/bin/env ruby
require 'logger'
require 'vendor/csp/lib/csp'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/lib')
require 'resque/server'

use Rack::ShowExceptions
require 'test-failures/fail'

use Jabs::Rack::Static, :urls => '/jabs', :root => Pathname.new(__FILE__).dirname.expand_path+'lib/resque/server'

run Rack::URLMap.new  \
  "/" => Resque::Server.new
  # "/csp" => CSP::Aplication.new
