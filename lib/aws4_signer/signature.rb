class Aws4Signer
  class Signature
    def initialize(access_key_id, secret_access_key, region, service, verb, uri, headers, body)
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @region = region
      @service = service
      @verb = verb
      @uri = uri
      @headers = headers.dup
      @body = body

      @headers.each do |name, value|
        if value.kind_of?(Array)
          @headers[name] = value.first
        end
      end

      @headers["x-amz-date"] ||= @headers.delete("X-Amz-Date")
      unless @headers["x-amz-date"]
        @date = Time.now.utc
        @headers["x-amz-date"] = @date.strftime("%Y%m%dT%H%M%SZ")
      end
      @headers["Host"] ||= @headers.delete("host") || uri.host
    end

    attr_reader :region, :service, :verb, :uri, :headers, :body, :access_key_id, :secret_access_key

    def attach_to_http_request(req)
      headers.each do |name, value|
        req[name.downcase] = value
      end

      req["x-amz-content-sha256"] = Digest::SHA2.hexdigest(req.body || '', 256)
      req["authorization"] = authorization_header

      req
    end

    def authorization_header
      "AWS4-HMAC-SHA256 " \
        "Credential=#{@access_key_id}/#{scope}," \
        "SignedHeaders=#{signed_headers}," \
        "Signature=#{signature}"
    end

    def date
      @date ||= begin
        time = Time.strptime(headers["x-amz-date"],"%Y%m%dT%H%M%SZ")
        time += time.utc_offset
        time.utc
      end
    end

    def canonical_headers
      @canonical_headers ||= begin
        signed = []
        hs = headers.sort_by { |name, _| name.downcase }.flat_map { |name, value|
          next if name == "Authorization"

          signed << name.downcase
          case value
          when Array
            value.each do |v|
              "#{name.downcase}:#{v.to_s.strip}\n"
            end
          else
            "#{name.downcase}:#{value.to_s.strip}\n"
          end
        }.compact.join.freeze

        @signed_headers = signed.join(";").freeze
        hs
      end
    end

    def signed_headers
      canonical_headers; @signed_headers
    end

    def hashed_payload
      @hashed_payload ||= Digest::SHA2.hexdigest(body, 256)
    end

    def canonical_request
      @canonical_request ||= [
        @verb.upcase,
        @uri.path,
        @uri.query,
        canonical_headers,
        signed_headers,
        hashed_payload,
      ].join("\n")
    end

    def scope
      "#{date.strftime("%Y%m%d")}/#{@region}/#{service}/aws4_request"
    end

    def string_to_sign
      @string_to_sign ||= [
        "AWS4-HMAC-SHA256",
        headers["x-amz-date"],
        scope,
        Digest::SHA2.hexdigest(canonical_request, 256),
      ].join("\n")
    end

    def date_key
      @date_key ||= hmac("AWS4#{@secret_access_key}", date.strftime("%Y%m%d"))
    end

    def date_region_key
      @date_region_key ||= hmac(date_key, region)
    end

    def date_region_service_key
      @date_region_service_key ||= hmac(date_region_key, service)
    end

    def signing_key
      @signing_key ||= hmac(date_region_service_key, 'aws4_request')
    end

    def signature
      @signature ||= hmac(signing_key, string_to_sign, :hex)
    end

    private

    def hmac(key, data, hex = false)
      hm = OpenSSL::HMAC.new(key, OpenSSL::Digest.new('sha256'))
      hm.update(data)

      if hex
        hm.hexdigest
      else
        hm.digest
      end
    end
  end
end
