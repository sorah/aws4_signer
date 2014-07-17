require_relative './test_helper'
require 'minitest/autorun'
require 'aws4_signer'

require 'uri'
require 'net/http'

describe Aws4Signer do
  let(:signer) { Aws4Signer.new('KEYKEYKEY','THISISSECRET', 'xx-region-1', 'svc') }
  let(:uri) { URI('https://example.org/foo/bar?baz=blah') }

  describe "#sign" do
    it "returns Signature" do
      signature = signer.sign('PUT', uri, headers: {'foo' => 'bar'}, body: 'hello')

      assert signature.is_a?(Aws4Signer::Signature)
      assert_equal 'KEYKEYKEY', signature.access_key_id
      assert_equal 'THISISSECRET', signature.secret_access_key
      assert_equal 'xx-region-1', signature.region
      assert_equal 'svc', signature.service
      assert_equal 'PUT', signature.verb
      assert_equal uri, signature.uri
      assert_equal 'hello', signature.body
      assert_equal 'bar', signature.headers['foo']
    end
  end
end
