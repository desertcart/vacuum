# frozen_string_literal: true

require 'vacuum/response'
require 'net/http'
require 'uri'
require 'aws-sigv4'

module Vacuum
  # An Amazon Product Advertising API request.
  class Request
    SERVICE = 'ProductAdvertisingAPI'

    attr_accessor :res
    attr_reader :access_key, :secret_key, :marketplace, :partner_tag, :partner_type

    def initialize(access_key:,
                   secret_key:,
                   partner_tag:,
                   marketplace: :us,
                   partner_type: 'Associates',
                   resources: nil)
      @res = resources if resources
      @access_key = access_key
      @secret_key = secret_key
      @partner_tag = partner_tag
      @partner_type = partner_type
      @marketplace = marketplace
    end

    def get_browse_nodes(browse_node_ids:,
                         languages_of_preference: nil,
                         marketplace: nil)
      @res = ['BrowseNodes.Ancestor', 'BrowseNodes.Children']
      @marketplace = marketplace if marketplace

      body = {}.tap do |hsh|
        hsh[:BrowseNodeIds] = Array(browse_node_ids)
        if languages_of_preference
          hsh[:LanguagesOfPreference] = languages_of_preference
        end
      end

      request('GetBrowseNodes', body)
    end

    def get_items(item_ids:,
                  resources: nil,
                  condition: nil,
                  currency_of_preference: nil,
                  languages_of_preference: nil,
                  marketplace: nil,
                  offer_count: nil)
      @res = resources if resources
      @marketplace = marketplace if marketplace

      body = {}.tap do |hsh|
        hsh[:ItemIds] = Array(item_ids)
        hsh[:Condition] = condition if condition
        if currency_of_preference
          hsh[:CurrencyOfPreference] = currency_of_preference
        end
        if languages_of_preference
          hsh[:LanguagesOfPreference] = languages_of_preference
        end
        hsh[:OfferCount] = offer_count if offer_count
      end

      request('GetItems', body)
    end

    def get_variations(asin:,
                       resources: nil,
                       condition: nil,
                       currency_of_preference: nil,
                       languages_of_preference: nil,
                       marketplace: nil,
                       offer_count: nil,
                       variation_count: nil,
                       variation_page: nil)
      @res = resources if resources
      @marketplace = marketplace if marketplace

      body = {}.tap do |hsh|
        hsh[:ASIN] = asin
        hsh[:Condition] = condition if condition
        if currency_of_preference
          hsh[:CurrencyOfPreference] = currency_of_preference
        end
        if languages_of_preference
          hsh[:LanguagesOfPreference] = languages_of_preference
        end
        hsh[:OfferCount] = offer_count if offer_count
        hsh[:VariationCount] = variation_count if variation_count
        hsh[:VariationPage] = variation_page if variation_page
      end

      request('GetVariations', body)
    end

    private

    def request(operation, body)
      raise ArgumentError unless OPERATIONS.include?(operation)

      body = default_body.merge(body).to_json
      signature = sign(operation, body)
      uri = URI.parse(market.endpoint(operation))
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json; charset=UTF-8'
      request_headers(operation, signature).each do |key, value|
        request[key] = value
      end
      request.body = body

      req_options = {
        use_ssl: uri.scheme == 'https'
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      Response.new response
    end

    def sign(operation, body)
      signer.sign_request(
        http_method: 'POST',
        url: market.endpoint(operation),
        headers: headers(operation),
        body: body
      )
    end

    def default_body
      {
        'PartnerTag' => partner_tag,
        'PartnerType' => partner_type,
        'Marketplace' => market.site,
        'Resources' => res
      }
    end

    def market
      MARKETPLACES[marketplace]
    end

    def request_headers(operation, signature)
      headers(operation).merge(
        'Authorization' => signature.headers['authorization'],
        'X-Amz-Content-Sha256' => signature.headers['x-amz-content-sha256'],
        'X-Amz-Date' => signature.headers['x-amz-date'],
        'Host' => market.host
      )
    end

    def headers(operation)
      {
        'X-Amz-Target' => "com.amazon.paapi5.v1.#{SERVICE}v1.#{operation}",
        'Content-Encoding' => 'amz-1.0'
      }
    end

    def signer
      Aws::Sigv4::Signer.new(
        service: SERVICE,
        region: market.region,
        access_key_id: access_key,
        secret_access_key: secret_key,
        http_method: 'POST',
        endpoint: market.host
      )
    end
  end
end
