require 'fluent/plugin/formatter'

module Fluent::Plugin
    class SingleMessageFormatter < Formatter
      Fluent::Plugin.register_formatter('single_message', self)

      config_param :message_key, :string, :default => 'message'
      #config_param :message_key, :string, :default => 'log'
      config_param :add_newline, :bool, :default => true

      def configure(conf)
        super
      end

      def format(tag, time, record)
        text = "#{record[@message_key].to_s}"
        text << "\n" if @add_newline
      end
    end
end
