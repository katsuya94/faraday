require File.expand_path('../integration', __FILE__)

module Adapters
  class NetHttpPersistentTest < Faraday::TestCase

    def adapter() :net_http_persistent end

    Integration.apply(self, :NonParallel) do
      def setup
        if defined?(Net::HTTP::Persistent)
          # work around problems with mixed SSL certificates
          # https://github.com/drbrain/net-http-persistent/issues/45
          if Net::HTTP::Persistent.instance_method(:initialize).parameters.first == [:key, :name]
            Net::HTTP::Persistent.new(name: 'Faraday').reconnect_ssl
          else
            Net::HTTP::Persistent.new('Faraday').ssl_cleanup(4)
          end
        end
      end if ssl_mode?

      def test_reuses_tcp_sockets
        # Ensure that requests are not reused from previous tests
        Thread.current.keys
          .select { |key| key.to_s =~ /\Anet_http_persistent_Faraday_/ }
          .each { |key| Thread.current[key] = nil }

        sockets = []
        tcp_socket_open_wrapped = Proc.new do |*args, &block|
          socket = TCPSocket.__minitest_stub__open(*args, &block)
          sockets << socket
          socket
        end

        TCPSocket.stub :open, tcp_socket_open_wrapped do
          conn = create_connection
          conn.post("/echo", :foo => "bar")
          conn.post("/echo", :foo => "baz")
        end

        assert_equal 1, sockets.count
      end
    end

    def test_custom_adapter_config
      url = URI('https://example.com:1234')

      adapter = Faraday::Adapter::NetHttpPersistent.new do |http|
        http.idle_timeout = 123
      end

      http = adapter.send(:net_http_connection, :url => url, :request => {})
      adapter.send(:configure_request, http, {})

      assert_equal 123, http.idle_timeout
    end
  end
end
