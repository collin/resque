#!/usr/bin/env ruby
require 'logger'
require 'vendor/csp/lib/csp'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/lib')
require 'resque/server'

use Rack::ShowExceptions

run Rack::URLMap.new  \
  "/" => Resque::Server.new
  # "/csp" => CSP::Aplication.new
