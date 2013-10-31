require "gorgon_bunny/compatibility"

module GorgonBunny
  # Represents AMQP 0.9.1 exchanges.
  #
  # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
  # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
  class Exchange

    include GorgonBunny::Compatibility


    #
    # API
    #

    # @return [GorgonBunny::Channel]
    attr_reader :channel

    # @return [String]
    attr_reader :name

    # Type of this exchange (one of: :direct, :fanout, :topic, :headers).
    # @return [Symbol]
    attr_reader :type

    # @return [Symbol]
    # @api plugin
    attr_reader :status

    # Options hash this exchange instance was instantiated with
    # @return [Hash]
    attr_accessor :opts


    # The default exchange. Default exchange is a direct exchange that is predefined.
    # It cannot be removed. Every queue is bind to this (direct) exchange by default with
    # the following routing semantics: messages will be routed to the queue withe same
    # same name as message's routing key. In other words, if a message is published with
    # a routing key of "weather.usa.ca.sandiego" and there is a queue Q with this name,
    # that message will be routed to Q.
    #
    # @param [GorgonBunny::Channel] channel_or_connection Channel to use. {GorgonBunny::Session} instances
    #                                               are only supported for backwards compatibility.
    #
    # @example Publishing a messages to the tasks queue
    #   channel     = GorgonBunny::Channel.new(connection)
    #   tasks_queue = channel.queue("tasks")
    #   GorgonBunny::Exchange.default(channel).publish("make clean", routing_key => "tasks")
    #
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf AMQP 0.9.1 specification (Section 2.1.2.4)
    # @note Do not confuse default exchange with amq.direct: amq.direct is a pre-defined direct
    #       exchange that doesn't have any special routing semantics.
    # @return [Exchange] An instance that corresponds to the default exchange (of type direct).
    # @api public
    def self.default(channel_or_connection)
      self.new(channel_from(channel_or_connection), :direct, GorgonAMQ::Protocol::EMPTY_STRING, :no_declare => true)
    end

    # @param [GorgonBunny::Channel] channel_or_connection Channel this exchange will use. {GorgonBunny::Session} instances are supported only for
    #                                               backwards compatibility with 0.8.
    # @param [Symbol,String] type                   Exchange type
    # @param [String] name                          Exchange name
    # @param [Hash] opts                            Exchange properties
    #
    # @option opts [Boolean] :durable (false)      Should this exchange be durable?
    # @option opts [Boolean] :auto_delete (false)  Should this exchange be automatically deleted when it is no longer used?
    # @option opts [Boolean] :arguments ({})       Additional optional arguments (typically used by RabbitMQ extensions and plugins)
    #
    # @see GorgonBunny::Channel#topic
    # @see GorgonBunny::Channel#fanout
    # @see GorgonBunny::Channel#direct
    # @see GorgonBunny::Channel#headers
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def initialize(channel_or_connection, type, name, opts = {})
      # old GorgonBunny versions pass a connection here. In that case,
      # we just use default channel from it. MK.
      @channel          = channel_from(channel_or_connection)
      @name             = name
      @type             = type
      @options          = self.class.add_default_options(name, opts)

      @durable          = @options[:durable]
      @auto_delete      = @options[:auto_delete]
      @arguments        = @options[:arguments]

      declare! unless opts[:no_declare] || predeclared? || (@name == GorgonAMQ::Protocol::EMPTY_STRING)

      @channel.register_exchange(self)
    end

    # @return [Boolean] true if this exchange was declared as durable (will survive broker restart).
    # @api public
    def durable?
      @durable
    end # durable?

    # @return [Boolean] true if this exchange was declared as automatically deleted (deleted as soon as last consumer unbinds).
    # @api public
    def auto_delete?
      @auto_delete
    end # auto_delete?

    # @return [Hash] Additional optional arguments (typically used by RabbitMQ extensions and plugins)
    # @api public
    def arguments
      @arguments
    end


    # Publishes a message
    #
    # @param [String] payload Message payload. It will never be modified by GorgonBunny or RabbitMQ in any way.
    # @param [Hash] opts Message properties (metadata) and delivery settings
    #
    # @option opts [String] :routing_key Routing key
    # @option opts [Boolean] :persistent Should the message be persisted to disk?
    # @option opts [Boolean] :mandatory Should the message be returned if it cannot be routed to any queue?
    # @option opts [Integer] :timestamp A timestamp associated with this message
    # @option opts [Integer] :expiration Expiration time after which the message will be deleted
    # @option opts [String] :type Message type, e.g. what type of event or command this message represents. Can be any string
    # @option opts [String] :reply_to Queue name other apps should send the response to
    # @option opts [String] :content_type Message content type (e.g. application/json)
    # @option opts [String] :content_encoding Message content encoding (e.g. gzip)
    # @option opts [String] :correlation_id Message correlated to this one, e.g. what request this message is a reply for
    # @option opts [Integer] :priority Message priority, 0 to 9. Not used by RabbitMQ, only applications
    # @option opts [String] :message_id Any message identifier
    # @option opts [String] :user_id Optional user ID. Verified by RabbitMQ against the actual connection username
    # @option opts [String] :app_id Optional application ID
    #
    # @return [GorgonBunny::Exchange] Self
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @api public
    def publish(payload, opts = {})
      @channel.basic_publish(payload, self.name, (opts.delete(:routing_key) || opts.delete(:key)), opts)

      self
    end


    # Deletes the exchange unless it is predeclared
    #
    # @param [Hash] opts Options
    #
    # @option opts [Boolean] if_unused (false) Should this exchange be deleted only if it is no longer used
    #
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @api public
    def delete(opts = {})
      @channel.deregister_exchange(self)
      @channel.exchange_delete(@name, opts) unless predeclared?
    end

    # Binds an exchange to another (source) exchange using exchange.bind AMQP 0.9.1 extension
    # that RabbitMQ provides.
    #
    # @param [String] source Source exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [GorgonBunny::Exchange] Self
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def bind(source, opts = {})
      @channel.exchange_bind(source, self, opts)

      self
    end

    # Unbinds an exchange from another (source) exchange using exchange.unbind AMQP 0.9.1 extension
    # that RabbitMQ provides.
    #
    # @param [String] source Source exchange name
    # @param [Hash] opts Options
    #
    # @option opts [String] routing_key (nil) Routing key used for binding
    # @option opts [Hash] arguments ({}) Optional arguments
    #
    # @return [GorgonBunny::Exchange] Self
    # @see http://rubybunny.info/articles/exchanges.html Exchanges and Publishing guide
    # @see http://rubybunny.info/articles/bindings.html Bindings guide
    # @see http://rubybunny.info/articles/extensions.html RabbitMQ Extensions guide
    # @api public
    def unbind(source, opts = {})
      @channel.exchange_unbind(source, self, opts)

      self
    end

    # Defines a block that will handle returned messages
    # @see http://rubybunny.info/articles/exchanges.html
    # @api public
    def on_return(&block)
      @on_return = block

      self
    end

    # Waits until all outstanding publisher confirms on the channel
    # arrive.
    #
    # This is a convenience method that delegates to {GorgonBunny::Channel#wait_for_confirms}
    #
    # @api public
    def wait_for_confirms
      @channel.wait_for_confirms
    end

    # @private
    def recover_from_network_failure
      # puts "Recovering exchange #{@name} from network failure"
      declare! unless predefined?
    end


    #
    # Implementation
    #

    # @private
    def handle_return(basic_return, properties, content)
      if @on_return
        @on_return.call(basic_return, properties, content)
      else
        # TODO: log a warning
      end
    end

    # @return [Boolean] true if this exchange is a pre-defined one (amq.direct, amq.fanout, amq.match and so on)
    def predefined?
      (@name == GorgonAMQ::Protocol::EMPTY_STRING) || !!(@name =~ /^amq\.(direct|fanout|topic|headers|match)/i)
    end # predefined?
    alias predeclared? predefined?

    protected

    # @private
    def declare!
      @channel.exchange_declare(@name, @type, @options)
    end

    # @private
    def self.add_default_options(name, opts, block)
      { :exchange => name, :nowait => (block.nil? && !name.empty?) }.merge(opts)
    end

    # @private
    def self.add_default_options(name, opts)
      # :nowait is always false for GorgonBunny
      h = { :queue => name, :nowait => false }.merge(opts)

      if name.empty?
        {
          :passive     => false,
          :durable     => false,
          :auto_delete => false,
          :arguments   => nil
        }.merge(h)
      else
        h
      end
    end
  end
end
