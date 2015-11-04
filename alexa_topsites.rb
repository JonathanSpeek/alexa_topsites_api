#!/usr/bin/ruby

require "cgi"
require "base64"
require "openssl"
require "digest/sha1"
require "uri"
require "net/https"
require "rexml/document"
require "time"

if ARGV.length < 4
  $stderr.puts "Usage: topsites.rb ACCESS_KEY_ID SECRET_ACCESS_KEY COUNTRY_CODE MAX"
  exit(-1)
else
  access_key_id = ARGV[0]
  secret_access_key = ARGV[1]
  country_code = ARGV[2]
  max = ARGV[3]
end

SERVICE_HOST = "ats.amazonaws.com"

# escape str to RFC 3986
def escapeRFC3986(str)
  return URI.escape(str, /[^A-Za-z0-9\-_.~]/)
end


def get_sites(access_key_id, country_code, secret_access_key, start, count)
  action = "TopSites"
  responseGroup = "Country"

  timestamp = (Time::now).utc.strftime("%Y-%m-%dT%H:%M:%S.000Z")

  query = {
    "Action" => action,
    "AWSAccessKeyId" => access_key_id,
    "Timestamp" => timestamp,
    "ResponseGroup" => responseGroup,
    "Start" => start,
    "Count" => count,
    "CountryCode" => country_code,
    "SignatureVersion" => 2,
    "SignatureMethod" => "HmacSHA1"
  }


  query_str = query.sort.map { |k, v| k + "=" + escapeRFC3986(v.to_s()) }.join('&')

  sign_str = "GET\n" + SERVICE_HOST + "\n/\n" + query_str

  signature = OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new("sha1"),
    secret_access_key, sign_str)
  query_str += "&Signature=" + escapeRFC3986(Base64.encode64(signature).strip)

  url = URI.parse("http://" + SERVICE_HOST + "/?" + query_str)

  xml = REXML::Document.new(Net::HTTP.get(url))

  REXML::XPath.each(xml, "//aws:DataUrl") { |el| puts el.text }
end


start = 1
count = 100

while start < max.to_i do
  get_sites(access_key_id, country_code, secret_access_key, start, count)
  start += count
end
