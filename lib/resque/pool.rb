require 'dnssd'
require 'eventmachine'
require 'uuid'

Thread.abort_on_exception = true
module Resque
  module Pool
    Version = "0.0.0".freeze
    Service = "_resquepool._tcp".freeze
        
    def self.list &block
      list = {}
      peers = []
      service = DNSSD.browse(Service) do |reply|
        list[reply.name] = reply
        resolver_service = DNSSD.resolve(reply.name, reply.type, reply.domain) do |reply|
          peers << reply
        end
        EventMachine.add_timer(5) { resolver_service.stop; }
      end
      EventMachine.add_timer(5) { service.stop; yield(list, peers) }
    end
    
    def self.start(options={})
      EventMachine.run do
        peer = Peer.new(options)
        EventMachine.start_server(peer.config[:bind_address], peer.config[:port], Connection, peer)
        peer.register_bonjour
      end
    end
    
    def self.set_concurrency_level(level)
      list do |list, peers|
        peers.each_with_index do |peer, index|
          EventMachine.connect(peer.target, peer.port, Resque::Pool::Controller, level)
        end
      end
    end
  end
end