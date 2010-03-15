module Resque
  class QueueSet < Set
    def initialize(key, queue_class=Queue)
      super()
      Resque.redis.smembers("#{key}").each do |queue_name|
        add queue_class.new(queue_name)
      end
    end
  end
  
  class Queue
    class WontDeleteNonEmptyQueue < StandardError; end
    
    def initialize(queue_name)
      @queue_name = queue_name
    end
    
    def delete
      raise WontDeleteNonEmptyQueue if any?
      Resque.remove_queue(@queue_name)
    end
    
    def failure_queues
      QueueSet.new("failed:per_queue:#{name}", FailureQueue)
    end
    
    def key
      @queue_name
    end
    
    def any?
      count > 0
    end
    
    def name
      @queue_name.to_s
    end
    alias to_s name
    
    def count
      Resque.size(key)
    end
    alias size count
    
    def <=>(other)
      name <=> other.name
    end
  end
  
  class FailureQueue < Queue
    def method_missing(method_name, *args, &block)
      data[method_name.to_s] or super
    end
    
    def data
      @data ||= Resque.list_range(key, 0)
    end
    
    def backtrace
      trace = {}
      data["backtrace"].map do |line|
        trace[%{txmt://open?url=file://#{line.gsub /:([\d]+):in `[\w]+'$/, "&line=#{$1}"}}] = line
      end
      trace
    end
    
    def unimplemented
      raise "Unimplemented"
    end
    
    def queue_name
      queue, error = *@queue_name.gsub(/^failures:/, '').split(':')
      
      "#{queue}: #{error}"
    end
    
    def count
      Resque.redis.llen(@queue_name).to_i
    end
    
    def reschedule
      while(failed = Resque.decode(Resque.redis.lpop(@queue_name))) do
        Resque::Job.create failed["queue"].gsub('queue_name', ''), failed["payload"]["class"], *failed["payload"]["args"]
        Resque.redis.decr("failure_counter")
        Resque.redis.decr("stat:failed")
      end
    end
    alias remove unimplemented
  end
end