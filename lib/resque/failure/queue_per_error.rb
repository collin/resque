module Resque
  module Failure
    FailureCounter = :failure_counter
    FailureQueues = :failure_queues
    
    def self.failure_queues
      QueueSet.new(FailureQueues, FailureQueue)
    end
    
    # A Failure backend that stores exceptions in Redis. This implementation stores an individual queue per
    # each class of error. This allows them to be managed with greater orthogonality.
    class QueuePerError < Redis
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
        # Add to the correct failure list.
        Resque.redis.rpush(failure_queue_name, data)
        # Add error queue to the error queue set.
        Resque.redis.set_add(FailureQueues, failure_queue_name)
        # Add error queue to list of error queues for this queue
        Resque.redis.set_add(per_queue_failures(queue), failure_queue_name)
        # Increment the master failure counter.
        Resque.redis.incr(FailureCounter)
      end
      
      def failure_queue_name
        "failed:#{exception.class.name}"
      end
      
      def per_queue_failures(queue)
        "failed:per_queue:#{queue}"
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
      
    end
  end
end
