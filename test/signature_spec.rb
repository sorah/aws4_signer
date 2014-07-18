require_relative './test_helper'
require 'minitest/autorun'
require 'aws4_signer/signature'

require 'uri'
require 'digest/sha2'

describe Aws4Signer::Signature do
  let(:uri) { URI('https://example.org/foo/bar?baz=blah') }
  let(:verb) { 'PUT' }
  let(:headers) do
    {'x-foo' => 'bar'}
  end
  let(:body) { 'hello' }
  let(:options) { {} }

  let(:signature) do
    Aws4Signer::Signature.new(
      'AKID',
      'SECRET',
      'xx-region-1',
      'svc',
      verb,
      uri,
      headers,
      body,
      **options
    )
  end

  describe "headers" do
    describe "without x-amz-date" do
      it "assigns" do
        assert signature.headers['x-amz-date'].is_a?(String)
      end
    end

    describe "with x-amz-date" do
      before do
        headers['x-amz-date'] = '20140222T070605Z'
      end

      it "doesn't assign" do
        assert signature.headers['x-amz-date'].is_a?(String)
        assert_equal Time.utc(2014,02,22,07,06,05), signature.date
      end
    end

    describe "without host" do
      it "assigns" do
        assert_equal 'example.org', signature.headers['Host']
      end
    end

    describe "with host" do
      before do
        headers['host'] = 'example.com'
      end

      it "doesn't assign" do
        assert_equal 'example.com', signature.headers['Host']
      end
    end

    describe "with security token" do
      let(:options) { {security_token: 'session-token'} }

      it "assigns x-amz-security-token" do
        assert_equal 'session-token', signature.headers['x-amz-security-token']
      end
    end
  end

  describe "#attach_to_http_request" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "assigns headers" do
      headers = {}
      class << headers
        def body
          'hello'
        end
      end
      signature.attach_to_http_request(headers)

      assert_equal 'example.org', headers['host']
      assert_equal '20140222T070605Z', headers['x-amz-date']
      assert_equal 'bar', headers['x-foo']
      assert_equal signature.authorization_header, headers['authorization']
      assert_equal Digest::SHA2.hexdigest('hello', 256), headers['x-amz-content-sha256']
    end
  end

  describe "#authorization_header" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "returns" do
      assert_equal 'AWS4-HMAC-SHA256 '\
        'Credential=AKID/20140222/xx-region-1/svc/aws4_request,' \
        'SignedHeaders=host;x-amz-date;x-foo,' \
        'Signature=2845eebf2510f52010a9d9e228d4b60d4dd33fb7e9f349fb21bd6a533bfc37b6',
        signature.authorization_header
    end
  end

  describe "#signature" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "return the sign" do
      assert_equal '2845eebf2510f52010a9d9e228d4b60d4dd33fb7e9f349fb21bd6a533bfc37b6', signature.signature
    end
  end

  describe "#canonical_headers,signed_headers" do
    let(:headers) do
      {
        'x-test-b' => '2',
        'X-Test-A' => '1',
        'x-test-c' => '3',
        'Authorization' => 'skip',
      }
    end

    it "ends with return" do
      assert_equal "\n", signature.canonical_headers[-1]
    end

    it "contains headers" do
      assert signature.canonical_headers.lines.include?("x-test-b:2\n")
      assert signature.canonical_headers.lines.include?("x-test-a:1\n") # downcase
      assert signature.canonical_headers.lines.include?("x-test-c:3\n")
      assert !signature.canonical_headers.lines.include?("Authorization:skip\n")

      %w(x-test-a x-test-b x-test-c).each do |name|
        assert signature.signed_headers.split(/;/).include?(name)
      end
    end

    it "sorts headers" do
      assert %w(host x-amz-date x-test-a x-test-b x-test-c),
        signature.canonical_headers.lines.map { |_| _.split(/:/,2).first }

      assert_equal 'host;x-amz-date;x-test-a;x-test-b;x-test-c', signature.signed_headers
    end
  end

  describe "#hashed_payload" do
    let(:body) { 'body' }

    it "returns hashed payloed" do
      assert_equal Digest::SHA2.hexdigest('body', 256), signature.hashed_payload
    end
  end

  describe "#canonical_request" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "returns canonical request" do
      canonical_request = signature.canonical_request

      assert_equal <<-EXPECTED.chomp, canonical_request
PUT
/foo/bar
baz=blah
host:example.org
x-amz-date:20140222T070605Z
x-foo:bar

host;x-amz-date;x-foo
#{Digest::SHA2.hexdigest('hello', 256)}
      EXPECTED
    end
  end

  describe "#scope" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "returns scope" do
      assert_equal '20140222/xx-region-1/svc/aws4_request', signature.scope
    end
  end

  describe "#string_to_sign" do
    before do
      headers['x-amz-date'] = '20140222T070605Z'
    end

    it "returns string to sign" do
      assert_equal <<-EXPECTED.chomp, signature.string_to_sign
AWS4-HMAC-SHA256
20140222T070605Z
20140222/xx-region-1/svc/aws4_request
#{Digest::SHA2.hexdigest(signature.canonical_request, 256)}
      EXPECTED
    end
  end
end
