Puppet::Functions.create_function(:consul_data_hash) do
  require 'net/http'
  require 'net/https'
  require 'json'
  require 'yaml'

  dispatch :consul_data_hash do
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def consul_init(options, context)
    @options = options
    @context = context

    unless @options.include?('host')
      raise ArgumentError, "'consul_data_hash': 'host' must be declared in Puppet.yaml when using this data_hash function"
    end

    unless @options.include?('port')
      raise ArgumentError, "'consul_data_hash': 'port' must be declared in Puppet.yaml when using this data_hash function"
    end

    unless @options.include?('consul_kv_path')
      raise ArgumentError, "'consul_data_hash': 'consul_kv_path' must be declared in Puppet.yaml when using this data_hash function"
    end

    unless @options.include?('data_format') && %w[json yaml].include?(@options['data_format'])
      raise ArgumentError, "'consul_data_hash': 'data_format' must be declared as type json or yaml"
    end

    if @options['consul_kv_path'] !~ /^\/v\d\/(kv)\//
      Puppet.warning("[hiera-consul]: We only support queries to kv and you asked #{consul_kv_path}, skipping")
    end

    @consul_kv_path = @options['consul_kv_path']
    @consul_data_format = @options['data_format']
    @graceful_failure = @options.include?('graceful_failure') ? @options['graceful_failure'] : false

    @consul = Net::HTTP.new(@options['host'], @options['port'])
    @consul.read_timeout = @options['http_read_timeout'] || 10
    @consul.open_timeout = @options['http_connect_timeout'] || 10

    if @options['use_ssl']
      @consul.use_ssl = true

      @consul.verify_mode = if @options['ssl_verify'] == false
                              OpenSSL::SSL::VERIFY_NONE
                            else
                              OpenSSL::SSL::VERIFY_PEER
                            end

      if @options['ssl_cert']
        store = OpenSSL::X509::Store.new
        store.add_cert(OpenSSL::X509::Certificate.new(File.read(@options['ssl_ca_cert'])))
        @consul.cert_store = store

        @consul.key = OpenSSL::PKey::RSA.new(File.read(options['ssl_cert']))
        @consul.cert = OpenSSL::X509::Certificate.new(File.read(@options['ssl_cert']))
      end
    else
      @consul.use_ssl = false
    end
  end

  def consul_data_hash(options, context)

    # Init a consul handler, and do some sanity checks
    consul_init(options, context)
    answer_hash = nil

    answer_text = wrapquery()
    unless not answer_text
      answer_hash = parse_data(answer_text)
      context.cache_all(answer_hash) if answer_hash
    end

    unless not answer_hash
      context.cache_all(answer_hash)
      return answer_hash
    end

    answer_hash

  end

  def parse_data(answer_text)
    answer_hash = nil
    if @consul_data_format == 'json'
      begin
        answer_hash = JSON.parse(answer_text)
      rescue JSON::ParserError
        Puppet.warning("[hiera-consul]: JSON Parse Error for path #{@consul_kv_path}")
        raise Exception, e.message unless @graceful_failure
      end
    elsif @consul_data_format == 'yaml'
      begin
        answer_hash = YAML.load(answer_text)
      rescue YAML::SyntaxError => e
        Puppet.warning("[hiera-consul]: YAML Parse Error for path #{@consul_kv_path}")
        raise Exception, e.message unless @graceful_failure
      end
    end

    answer_hash
  end


  private

  def token(path)
    # Token is passed only when querying kv store
    "&token=#{@options['token']}" if @options['token'] && path =~ /^\/v\d\/kv\//
  end

  def wrapquery()
    # Get a raw response, so we don't have to parse
    req_path = "#{@consul_kv_path}?raw"
    httpreq = Net::HTTP::Get.new("#{req_path}#{token(req_path)}")
    answer = nil
    begin
      result = @consul.request(httpreq)
    rescue Exception => e
      Puppet.warning('[hiera-consul]: Could not connect to Consul')
      raise Exception, e.message unless @graceful_failure
      return answer
    end
    unless result.is_a?(Net::HTTPSuccess)
      Puppet.warning("[hiera-consul]: HTTP response code was #{result.code}")
      return answer
    end
    Puppet.warning("[hiera-consul]: Answer was #{result.body}")
    answer = result.body
    answer
  end
end
