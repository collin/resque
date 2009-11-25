require 'dnssd'
require 'eventmachine'
Thread.abort_on_exception = true
module Resque
  class Pool
    Version = "0.0.0".freeze
    Service = "_resquepool._tcp".freeze
    Port = 2395
    
    class PoolConnection < EventMachine::Connection
      class PoolProtocolError < StandardError; end
      
      AddWorker = "1".freeze
      RemoveWorker = "2".freeze
      SetOption = "3".freeze
      
      def initialize(pool)
        @pool = pool
      end
      
      def receive_data(data)
        case data.slice!(0,1)
        when AddWorker
          @pool.add_worker
          send_data "OK\n"
        when RemoveWorker
          @pool.remove_worker
          send_data "OK\n"
        when SetOption
          key, value = *data.split(':')
          (key and value) or raise PoolProtocolError
          @pool.set_option(key, value)
          send_data "OK\n"
        else raise PoolProtocolError
        end
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
    
    attr_reader :workers
    
    def self.start
      pool = Pool.new
      EventMachine.run do
        EventMachine.start_server("127.0.0.1", 2395, PoolConnection, pool)
      end
    end

    def initialize
      @workers = []
      @config = {:queues => ["*"]}
      register_bonjour
    end
    
    def add_worker
      worker = nil
      begin
        worker = Resque::Pool::PoolWorker.new(self)
        worker.verbose = @config[:logging] || @config[:verbose]
        worker.very_verbose = @config[:vverbose]
        workers << worker
      rescue Resque::NoQueueError
        abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
      end
      
      child = fork do
        puts "*** Starting worker #{worker}"
        worker.work(@config[:interval] || 5) # interval, will block  
      end
      
      Process.detach(child)
    end
    
    def queues
      @config[:queues]
    end
    
    def set_option(key, value)
      @config[key].intern = Resque.decode(value.chomp)
    end
    
    def remove_worker
      worker = workers.shift
      worker.shutdown
    end
    
    def remove_all_workers
      while(workers.any?) do 
        remove_worker
      end
    end
    
    def self.list
      list = {}
      service = DNSSD.browse(Service) do |reply|
        list[reply.name] = reply
      end
      sleep 5
      service.stop
      list
    end
    
    def register_bonjour
      tr = DNSSD::TextRecord.new
      tr["description"] = "A dynamic Pool of Resque workers"

      DNSSD.register("ResquePool-#{`hostname`}:#{Port}", Service, 'local', 2395) do |rr|
        # puts "Registered Resque Pool on port 2395. Starting service."
      end
    end
  end
end