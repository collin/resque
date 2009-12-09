module Resque
  module Pool
    class Peer
      
      attr_reader :config
      
      def initialize(options={})
        @workers = []
        @children = {}
        @config = {
          :queues => ["*"],
          :port => 2395,
          :bind_address => "0.0.0.0"
          }.merge(options)
      end
    
      def set_concurrency_level(level)
        if level > concurrency_level
          (level - concurrency_level).times { add_worker }
        else
          (concurrency_level - level).times { remove_worker }
        end
      end
    
      def concurrency_level
        @workers.size
      end
    
      def add_worker
        worker = nil
        begin
          worker = Resque::Pool::Worker.new(self)
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
        puts puts "*** Stopping worker #{worker}"
        Process.kill("QUIT", @children[worker])
      end
    
      def remove_all_workers
        while(@workers.any?) do 
          remove_worker
        end
      end
      
      def register_bonjour
        DNSSD.register("ResquePool #{UUID.generate}", Service, "local", @config[:port]) do |reply|
          puts "#{reply.name}::#{reply.domain}::#{reply.type}"
        end
      end
    end
    
  end
end