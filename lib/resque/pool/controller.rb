module Resque
  module Pool
    class Controller < EventMachine::Connection
      def initialize(level)
        @level = level
      end
      
      def post_init
        EventMachine.next_tick do
          send_data "#{Resque::Pool::Connection::SetConcurrencyLevel}#{@level}"
          send_data Resque::Pool::Connection::EndSession
        end
      end
      
      def send_data(data)
        super("#{data}\n")
      end
    end
  end
end