module Resque
  module Pool
    class Connection < EventMachine::Connection
      EndSession = "0".freeze
      # AddWorker = "1".freeze
      # RemoveWorker = "2".freeze
      SetOption = "3".freeze
      SetConcurrencyLevel = "4".freeze
      PoolProtocolError = "PoolProtocolError\n".freeze
      Okay = "OK\n".freeze
      
      PoolOptions = [:logging, :verbose, :vverbose, :queues].freeze
      
      def initialize(peer)
        @peer = peer
      end
      
      def post_init
        puts "CONNECTION MADE"
      end
      
      def receive_data(data)
        puts "RECV: #{data}"
        case data.slice!(0,1)
        when EndSession
          close_connection
        # Adding and removing workers explicitly under review.
        # Prefer specifying a level and letting the peer work itself out.
        # when AddWorker
        #   @peer.add_worker
        #   okay!
        # when RemoveWorker
        #   @peer.remove_worker
        #   okay!
        when SetConcurrencyLevel
          @peer.set_concurrency_level(data.to_i)
          okay!
        when SetOption
          key, value = *data.split(':')
          key.nil? and return error!
          value.nil? and return error!
          key = key.intern
          PoolOptions.include?(key) or return error!
          @peer.set_option(key, value)
          okay!
        else
          error!
        end
      rescue
        error!
      end
      
      def error!
        send_data(PoolProtocolError)
      end
      
      def okay!
        send_data(Okay)
      end
      
      def unbind
        @peer.remove_all_workers
      end
    end
  end
end