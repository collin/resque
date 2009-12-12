module Resque
  module Pool
    class Peer
      
      attr_reader :config, :workers
      
      def initialize(options={})
        @workers = []
        @children = {}
        @config = {
          :queues => ["*"],
          :port => 2395,
          :bind_address => "0.0.0.0"
          }.merge(options)
      end
    
      def set_concurrency_level
        if workers_count < Resque.concurrency_level
          (Resque.concurrency_level - workers_count).times { add_worker }
        else
          (workers_count - Resque.concurrency_level).times { remove_worker }
        end
      end
    
      def workers_count
        @workers.size
      end
    
      def add_worker
        worker = nil
        begin
          worker = Resque::Worker.new(*@config[:queues])
          
          worker.verbose = @config[:logging] || @config[:verbose]
          worker.very_verbose = @config[:vverbose]
          @workers << worker
        rescue Resque::NoQueueError
          abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
        end
      
        child = fork do
          require @config[:load]
          Signal.trap("QUIT") { worker.shutdown }
          puts "*** Starting worker #{worker}"
          worker.work(@config[:interval] || 5) # interval, will block
        end
      
        Process.detach(child)
        @children[worker] = child
      end
    
      def queues
        return ["extract_relation_relations"]
        @config[:queues]
      end
    
      def set_option(key, value)
        @config[key] = Resque.decode(value.chomp)
        pp @config
      end
    
      def remove_worker
        return unless(worker = @workers.shift)
        puts "*** Stopping worker #{worker}"
        Process.kill("QUIT", @children[worker])
      end
    
      def remove_all_workers
        while(@workers.any?) do 
          remove_worker
        end
      end
      
    end
    
  end
end