require 'fluent/plugin/formatter'

module Fluent::Plugin
    class HostnameAndMessageFormatter < Formatter
      Fluent::Plugin.register_formatter('hostname_and_message', self)

      # config_param :message_key, :string, :default => 'message'
      config_param :message_key, :string, :default => 'parsed_log'
      config_param :add_newline, :bool, :default => true

      def configure(conf)
        super
      end

      def format(tag, time, record)
        # text = "#{record['hostname']} #{record[@message_key].to_s}"
        # text = "#{record['hostname']} #{record[@message_key].gsub(/\n/, '### NEW LINE ###')}"
        # text = "#{record['hostname']} #{record[@message_key].gsub(/\t/, ' ')}"
        text = "#{record['hostname']} #{record[@message_key].gsub(/\t/, ' ').to_s}"
        text << "\n" if @add_newline
      end
    end
end
