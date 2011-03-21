module Faye
  module Engine
    
    class Memory < Base
      def initialize(options)
        @clients   = {}
        @channels  = {}
        @messages  = {}
        @namespace = Namespace.new
        super
      end
      
      def create_client(&callback)
        client_id = @namespace.generate
        @clients[client_id] = Set.new
        ping(client_id)
        callback.call(client_id)
      end
      
      def destroy_client(client_id, &callback)
        return unless @clients.has_key?(client_id)
        @clients[client_id].each do |channel|
          unsubscribe(client_id, channel)
        end
        remove_timeout(client_id)
        @clients.delete(client_id)
        @messages.delete(client_id)
        callback.call if callback
      end
      
      def client_exists(client_id, &callback)
        callback.call(@clients.has_key?(client_id))
      end
      
      def ping(client_id)
        timeout = @options[:timeout]
        return unless Numeric === timeout
        remove_timeout(client_id)
        add_timeout(client_id, 2 * timeout) { destroy_client(client_id) }
      end
      
      def subscribe(client_id, channel, &callback)
        @clients[client_id] ||= Set.new
        @channels[channel]  ||= Set.new
        @clients[client_id].add(channel)
        @channels[channel].add(client_id)
        callback.call(true) if callback
      end
      
      def unsubscribe(client_id, channel, &callback)
        @clients[client_id].delete(channel) if @clients.has_key?(client_id)
        @channels[channel].delete(client_id) if @channels.has_key?(channel)
        callback.call(true) if callback
      end
      
      def publish(message)
        channels = Channel.expand(message['channel'])
        channels.each do |channel|
          next unless clients = @channels[channel]
          clients.each do |client_id|
            @messages[client_id] ||= Set.new
            @messages[client_id].add(message)
            flush(client_id)
          end
        end
      end
      
    private
      
      def flush(client_id)
        return unless conn = connection(client_id, false) and
               messages = @messages.delete(client_id)
        
        messages.each(&conn.method(:deliver))
      end
    end
    
    register 'memory', Memory
    
  end
end

