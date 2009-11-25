module Resque
  class QueueSet < Set
    def initialize(key, queue_class=Queue)
      super(Resque.redis.set_members("resque:#{key}").map { |queue_name| queue_class.new(queue_name) })
    end
  end
  
  class FailureQueue < Queue
    def method_missing(method_name, *args)
      data[method_name.intern] or super
    end
    
    def data
      @data ||= Resque.peek(@queue_name)
    end
    
    def backtrace
      backtrace.map do |line|
        "txmt://#{line.gsub /:([\d]+)$/, "&line=$1"}"
      end
    end
    
    def unimplemented
      raise "Unimplemented"
    end
    alias schedule unimplemented
    alias remove unimplemented
  end
  
  class Queue
    def initialize(queue_name)
      @queue_name = queue_name
    end
    
    def failure_queues
      QueueSet.new("failed:per_queue:#{name}", FailureQueue)
    end
    
    def any?
      count > 0
    end
    
    def name
      @queue_name.to_s
    end
    alias to_s name
    
    def count
      Resque.redis.llen(@queue_name).to_i
    end
    alias size count
    
    def <=>(other)
      name <=> other.name
    end
  end
end