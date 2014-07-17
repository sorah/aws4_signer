require 'aws4_signer'
require 'uri'
require 'net/http'
require 'net/https'

bucket, key = ARGV

unless bucket && key && ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"] && ENV["AWS_REGION"]
  puts "Usage: #{$0} bucket key"
  puts "Specify AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION via environment variable"
  exit 2
end

signer = Aws4Signer.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"], ENV["AWS_REGION"], 's3')
uri = URI("https://s3-#{ENV["AWS_REGION"]}.amazonaws.com/#{bucket}/#{key}")
Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http| 
  req = Net::HTTP::Get.new(uri)
  signer.sign_http_request(req)

  response = http.request(req)
  puts response.body
end
