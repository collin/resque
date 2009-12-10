module Resque
  module Pool
    class Worker < ::Resque::Worker
      attr_reader :peer
      
      def initialize(peer)
        @peer = peer
      end
      
      def queues
        peer.queues
      end
      
    end
  end
end