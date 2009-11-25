module Resque
  class QueueSet < Set
    def initialize(key, queue_class=Queue)
      super()
      Resque.redis.set_members("resque:#{key}").each do |queue_name|
        add queue_class.new(queue_name)
      end
    end
  end
  
  class Queue
    def initialize(queue_name)
      @queue_name = queue_name
    end
    
    def failure_queues
      QueueSet.new("failed:per_queue:#{name}", FailureQueue)
    end
    
    def key
      "#{@queue_name}"
    end
    
    def any?
      count > 0
    end
    
    def name
      @queue_name.to_s
    end
    alias to_s name
    
    def count
      Resque.redis.llen(key).to_i
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
    alias schedule unimplemented
    alias remove unimplemented
  end
end