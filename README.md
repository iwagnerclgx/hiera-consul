
Based on [lynxman/hiera_consul](https://github.com/lynxman/hiera-consul) and fork by [iwagnerclgx](https://github.com/iwagnerclgx/hiera-consul)

[consul](http://www.consul.io) is an orchestration mechanism with fault-tolerance based on the gossip protocol and a key/value store that is strongly consistent. Hiera-consul will allow hiera to write to the k/v store for metadata centralisation and harmonisation.

## Installation

Clone and build:

    puppet module build
    puppet module install /path/to/module.tar.gz

Ensure the function `consul_lookup_key` is available in your Puppet environment; on my box this is `$PUPPET_DIR/lib/ruby/vendor_ruby/puppet/functions`

## Configuration

This is my `hiera.yaml`, YMMV

    version: 5
    
    hierarchy:
      - name: Consul
        lookup_key: consul_lookup_key
        uris:
          - "/v1/kv/puppet/nodes/%{trusted.certname}"
          - "/v1/kv/puppet/environments/%{::environment}"
          - "/v1/kv/puppet/common"
        options:
          host: localhost
          port: 8500
          use_ssl: false
          ignore_404: true

## Parameters

A list of all parameters with examples is below

      host: 127.0.0.1
      port: 8500
      use_ssl: false
      ssl_verify: false
      ssl_cert: /path/to/cert
      ssl_key: /path/to/key
      ssl_ca_cert: /path/to/ca/cert
      failure: graceful
      ignore_404: true
      token: acl-uuid-token

## Notes

The upstream packages included a host of other functions, I haven't gone through and tested these myself (yet). Please see README from [upstream](https://github.com/lynxman/hiera-consul)

## CREDITS

Please see README from [upstream](https://github.com/lynxman/hiera-consul)
