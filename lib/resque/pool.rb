require 'dnssd'
require 'eventmachine'
require 'uuid'

Thread.abort_on_exception = true
module Resque
  def self.concurrency_level=(level)
    redis.set('stat:concurrency_level', level)
  end
  
  def self.concurrency_level
    redis.get('stat:concurrency_level').to_i
  end
  
  module Pool
    def self.start(options={})
      peer = Peer.new(options)
      loop do 
        peer.set_concurrency_level
        sleep 5
      end
    end
  end
end