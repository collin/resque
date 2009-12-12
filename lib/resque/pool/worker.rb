module Resque
  module Pool
    class Worker < ::Resque::Worker
      attr_reader :peer
      
      def initialize(peer)
        @peer = peer
      end
      
    end
  end
end