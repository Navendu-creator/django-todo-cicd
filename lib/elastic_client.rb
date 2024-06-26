require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'elasticsearch'
require 'hashie'

class ElasticClient

  attr_accessor :client

  def initialize
    @client = Elasticsearch::Client.new host: ENV['ELASTICSEARCH_URL'], adapter: :typhoeus # ,  log: true, trace: true
    @defaults = {
        index: 'extension-api',
        type: 'families'
    }
  end


  def get(id)
    begin
      search = @client.get(@defaults.merge({id: id}))
      res = Hashie::Mash.new search
      return res._source
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      puts "Record not found"
      return nil
    end
  end

  def search(body, options = {})
    @client.search(@defaults.merge({body: body}).merge options)
  end

  def index(id, body, options = {})
    @client.index(@defaults.merge({id: id, body: body}).merge options)
  end

  def bulk_index(data, options = {})
    body = []
    settings = @defaults.merge(options)
    data.each{|item|
      body.push( index: {_index: settings[:index], _type: settings[:type], _id: item['id']})
      body.push(item)
    }
    @client.bulk({body: body})
  end

  def delete_index
    begin
      @client.indices.delete index: @defaults[:index]
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      puts "Index not found"
    end
  end

  def create_index(body)
    @client.indices.create index: @defaults[:index], body: body
  end

  def index_exists?
    @client.indices.exists index: @defaults[:index]
  end

  def delete_ids(ids)
    @client.delete_by_query index: @defaults[:index], body: {query: { filtered: {filter: {ids: {values: ids}} }}}
  end


end