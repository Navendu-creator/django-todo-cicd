require 'rubygems'
require 'bundler/setup'

require 'dotenv'
Dotenv.load('config/.env')

require 'sinatra/base'
require 'sinatra/param'
require 'sinatra/reloader'
require 'config_for'
require 'json'

require('./lib/api_helper')
require('./lib/elastic_client')
require('./lib/api_config')
include ApiConfig

class ExtensionAPI < Sinatra::Base

  register Sinatra::Reloader
  register ConfigFor::Sinatra

  configure :local do
    enable :reloader
    also_reload './lib/*'
  end

  helpers Sinatra::Param, ApiHelper

  set :port, config_for(:app)[:port]
  set :show_exceptions, ApiConfig.environment == 'local' || development?

  before do
    content_type :json, charset: 'utf-8'
    headers(
        "Access-Control-Allow-Origin" => "*",
        "Cache-Control" => "public, s-maxage=3600"
    )
  end

  get '/families' do

    category_map = {
        'display' => 'Display',
        'serif' => 'Serif',
        'slab' => 'Slab Serif',
        'symbols' => 'Symbol',
        'script' => 'Script',
        'sans' => 'Sans Serif',
        'blackletter' => 'Blackletter',
        'nonwestern' => 'Non Latin',
        'any' => 'Any'
    }

    # parse and validate parameters
    param :page, Integer, default: 1
    param :limit, Integer, default: 20
    param :q, String, transform: lambda { |q| sanitize_search_string(q) }
    param :type, String, default: 'any', in: %w{webfonts desktopfonts any}
    param :category, String, default: 'any', in: category_map.keys
    param :similar_to, Integer
    param :ids, Array
    param :autocomplete, Boolean
    param :sort_by, String, default: lambda { params.has_key?('q') ? 'relevance' : 'bestsellers' },
          in: %w{alphabetic bestsellers newest relevance}
    param :sort_order, String, default: 'asc', in: %w{asc desc}, transform: :downcase
    param :client, String, default: 'anon'
    one_of(:similar_to, :ids, :q)

    # prepare sort order
    sort_map = {
        'alphabetic' => 'name.raw',
        'bestsellers' => 'bestseller_sortno',
        'newest' => 'design_year',
        'relevance' => '_score'
    }
    sort_by = sort_map[params[:sort_by]]
    sort_order = params[:sort_order]
    sort_order = 'desc' if sort_by == '_score'


    # perform search queries according to parameters

    from = (params[:page] - 1) * params[:limit]
    client = ElasticClient.new
    search_response = nil

    if params.has_key?('similar_to')
      # similar to
      family = client.get(params[:similar_to])
      if (family)
        similar_ids = family.similar_families.map { |similar| similar.id }
        query = {filter: {ids: {values: similar_ids}}}
        filters = get_filters(params, category_map)
        if (filters.size > 0)
          query = {filter: { bool: { must: filters << (query[:filter]) }}}
        end
        search_response = client.search(query)
      end
    elsif params.has_key?('autocomplete')
      # autocomplete
      if params.has_key?('q')
        q = params[:q]
        if not (q.nil? or q.empty?)
          term = "#{q}" # todo huh?
          defs = {sort: [{_score: 'desc'}], size: params[:limit], min_score: 1}
          family_auto_query = {query: {match: {'name.autocomplete' => {query: term}}}}
          filters = get_filters(params, category_map)
          if (filters.size > 0)
            family_auto_query = {
                query: {
                    filtered: {
                        filter:  {
                            bool: {
                                must: filters
                            }
                        },
                        query: family_auto_query[:query]
                     }
                }
            }
          end
          search_response = {
              families: client.search(defs.merge(family_auto_query)),
              designers: client.search(defs.merge({query: {match: {'name.autocomplete' => {query: term}}}}), {type: 'designers'}),
              foundries: client.search(defs.merge({query: {match: {'name.autocomplete' => {query: term}}}}), {type: 'foundries'}),
          }
        end
      end

    elsif params.has_key?('ids')
      # specific ids
      search_response = client.search({filter: {ids: {values: params[:ids]}}})
    else
      # category and searches
      body = auto_vivifying_hash

      body[:from] = from
      body[:size] = params[:limit]
      body[:sort] = [{"#{sort_by}" => sort_order}]

      filters = get_filters(params, category_map)
      if (filters.size > 0)
        body[:query][:filtered][:filter][:bool][:must] = filters
      end
      if params.has_key?('q')
        q = params[:q]
        if not (q.nil? or q.empty?)
          term ="#{q}"
          query = get_search_query term
          if (filters.size > 0)
            body[:query][:filtered][:query] = query
          else
            body[:query] = query
          end
        end
      end

      search_response = client.search(body)

    end

    response = format_response(search_response, params)
    response.to_json

  end

  run! if __FILE__ == $0
end




