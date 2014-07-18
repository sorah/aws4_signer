require 'uri'
require 'time'
require 'digest/sha2'
require 'openssl'

require 'net/http'
require 'net/https'

require "aws4_signer/version"
require 'aws4_signer/signature'

class Aws4Signer
  # to be exactly follow the AWS documentation, implement by ourselves
  def self.uri_encode(str)
    str.bytes.map do |c|
      if %w[- . _ ~].include?(c) || (?A .. ?Z).cover?(c) || (?a .. ?z).cover?(c) || (?0 .. ?9).cover?(c)
        c
      else
        "%#{c.ord.to_s(16)}"
      end
    end.join
  end

  def initialize(access_key_id, secret_access_key, region, service, security_token: nil)
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
    @region = region
    @service = service
    @security_token = security_token
  end

  def sign(verb, uri, headers: {}, body: '')
    raise ArgumentError, 'URI must provided' unless uri
    Signature.new(@access_key_id, @secret_access_key, @region, @service, verb, uri, headers, body, security_token: @security_token)
  end

  def sign_http_request(req, uri = nil)
    sign(
      req.method,
      uri || req.uri,
      headers: req.to_hash,
      body: req.body || '',
    ).tap do |signature|
      signature.attach_to_http_request(req)
    end
  end
end


