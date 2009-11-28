require 'dnssd'
require 'eventmachine'
require 'uuid'

Thread.abort_on_exception = true
module Resque
  class Pool
    Version = "0.0.0".freeze
    Service = "_resquepool._tcp".freeze
    
    attr_reader :config
    
    class PoolConnection < EventMachine::Connection
      EndSession = "0".freeze
      AddWorker = "1".freeze
      RemoveWorker = "2".freeze
      SetOption = "3".freeze
      PoolProtocolError = "PoolProtocolError\n".freeze
      PoolOptions = [:logging, :verbose, :vverbose, :queues].freeze
      
      def initialize(pool)
        @pool = pool
      end
      
      def receive_data(data)
        case data.slice!(0,1)
        when EndSession
          close_connection
        when AddWorker
          @pool.add_worker
          send_data "OK\n"
        when RemoveWorker
          @pool.remove_worker
          send_data "OK\n"
        when SetOption
          key, value = *data.split(':')
          key.nil? and return error!
          value.nil? and return error!
          key = key.intern
          PoolOptions.include?(key) or return error!
          @pool.set_option(key, value)
          send_data "OK\n"
        else
          error!
        end
      end
      
      def error!
        send_data(PoolProtocolError)
      end
      
      def unbind
        @pool.remove_all_workers
      end
    end
    
    class PoolWorker < ::Resque::Worker
      attr_reader :pool
      
      def initialize(pool)
        @pool = pool
      end

      def queues
        pool.queues
      end
    end
    
    def self.start(options={})
      EventMachine.run do
        pool = Pool.new(options)
        EventMachine.start_server(pool.config[:bind_address], pool.config[:port], PoolConnection, pool)
        pool.register_bonjour
      end
    end

    def initialize(options={})
      @workers = []
      @children = {}
      @config = {
        :queues => ["*"],
        :port => 2395,
        :bind_address => "0.0.0.0"
        }.merge(options)
    end
    
    def add_worker
      worker = nil
      begin
        worker = Resque::Pool::PoolWorker.new(self)
        worker.verbose = @config[:logging] || @config[:verbose]
        worker.very_verbose = @config[:vverbose]
        @workers << worker
      rescue Resque::NoQueueError
        abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
      end
      
      child = fork do
        Signal.trap("QUIT") { worker.shutdown }
        puts "*** Starting worker #{worker}"
        worker.work(@config[:interval] || 5) # interval, will block
      end
      
      Process.detach(child)
      @children[worker] = child
    end
    
    def queues
      @config[:queues]
    end
    
    def set_option(key, value)
      @config[key] = Resque.decode(value.chomp)
      pp @config
    end
    
    def remove_worker
      return unless(worker = @workers.shift)
      Process.kill("QUIT", @children[worker])
    end
    
    def remove_all_workers
      while(@workers.any?) do 
        remove_worker
      end
    end
    
    def self.list
      list = {}
      resolved = []
      service = DNSSD.browse(Service) do |reply|
        list[reply.name] = reply
        # Let's lookup the details
        resolver_service = DNSSD.resolve(reply.name, reply.type, reply.domain) do |reply|
          resolved << reply
        end
        sleep(2)
        resolver_service.stop
      end
      sleep 5
      service.stop
      [list, resolved]
    end
    
    def register_bonjour
      DNSSD.register("ResquePool #{UUID.generate}", Service, "local", @config[:port]) do |reply|
        puts "#{reply.name}::#{reply.domain}::#{reply.type}"
      end
    end
  end
end