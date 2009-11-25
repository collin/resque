module Resque
  module Failure
    FailureCounter = "failure_counter"
    FailureQueues = "resque:failure_queues"
    
    def self.failure_queues
      QueueSet.new("failure_queues", FailureQueue)
    end
    
    # A Failure backend that stores exceptions in Redis. This implementation stores an individual queue per
    # each class of error. This allows them to be managed with greater orthogonality.
    class QueuePerError < Base
      def save
        data = {
          :failed_at => Time.now.to_s,
          :payload   => payload,
          :error     => exception.to_s,
          :backtrace => exception.backtrace,
          :exception_class => exception.class.name,
          :worker    => worker.to_s,
          :queue     => queue
        }
        data = Resque.encode(data)
        # Add error queue to the error queue set.
        log Resque.redis.set_add(FailureQueues, per_queue_failures)
        # Add error queue to list of error queues for this queue
        log Resque.redis.rpush(per_queue_failures, data)
        # Increment the master failure counter.
        log Resque.redis.incr(FailureCounter)
      end
      
      def per_queue_failures
        "failures:#{queue}:#{exception.class.name.underscore}".gsub '/', '_'
      end
      
      def self.count
        # Now using the counter.
        Resque.redis[FailureCounter].to_i
        # Resque.redis.llen(:failed).to_i
      end
      
      def self.all(error_queue_name, start = 0, count = 1)
        Resque.list_range(error_queue_name, start, count)
      end
      
      def self.clear
        raise "Unimplented"
      end
      
      def self.url
        nil
      end
    end
  end
end
