require 'couch/db/version'
require 'net/http'
require 'json'
require 'objspace'
require 'openssl'

class Hash
  def include_symbol_or_string?(param)
    if param.is_a? Symbol or param.is_a? String
      include? param.to_sym or include? param.to_s
    else
      false
    end
  end
end

module Couch
  module BasicRequest
    def create_postfix(query_params, default='')
      if query_params
        params_a = []
        query_params.each do |key, value|
          params_a << "#{key}=#{value}"
        end
        postfix = "?#{params_a.join('&')}"
      else
        postfix = default
      end
      postfix
    end

    module Get
      # Returns parsed doc from database
      def get_doc(database, id, params={})
        res = get("/#{database}/#{CGI.escape(id)}#{create_postfix(params)}")
        JSON.parse(res.body)
      end

      def get_attachment_str(db, id, attachment)
        uri = URI::encode "/#{db}/#{id}/#{attachment}"
        get(uri).body
      end
    end

    module Head
      # Returns revision for given document
      def get_rev(database, id)
        res = head("/#{database}/#{CGI.escape(id)}")
        if res.code == '200'
          res['etag'].gsub(/^"|"$/, '')
        else
          nil
        end
      end
    end
  end

  # Bulk requests; use methods from Couch::BasicRequest
  module BulkRequest
    module Get
      # Returns an array of the full documents for given database, possibly filtered with given parameters.
      # We recommend you use all_docs instead.
      #
      # Note that the 'include_docs' parameter must be set to true for this.
      def get_all_docs(database, params)
        # unless params.include_symbol_or_string? :include_docs
        #   params.merge!({:include_docs => true})
        # end
        postfix = create_postfix(params)
        uri = URI::encode "/#{database}/_all_docs#{postfix}"
        res = get(uri)
        JSON.parse(res.body)['rows']
      end


      # If a block is given, performs the block for each +limit+-sized slice of _all_docs.
      # If no block is given, returns all docs by appending +limit+-sized slices of _all_docs.
      #
      # This method assumes your docs don't have the high-value Unicode character \ufff0. If it does, then behaviour is undefined. The reason why we use the startkey parameter instead of skip is that startkey is faster.
      def all_docs(db, limit=750, opts={}, &block)
        all_docs = []
        start_key = nil
        loop do
          opts = opts.merge({limit: limit})
          if start_key
            opts[:startkey]=start_key
          end
          docs = (lambda { |options| get_all_docs(db, options) }).call(opts)
          if docs.length <= 0
            break
          else
            if block
              block.call(docs)
            else
              all_docs < docs
            end
            start_key ="\"#{docs.last['_id']}\\ufff0\""
          end
        end
        all_docs.flatten
      end

      # Returns an array of all rows for given view.
      #
      # We recommend you use rows_for_view instead.
      def get_rows_for_view(database, design_doc, view, query_params=nil)
        postfix = create_postfix(query_params)
        uri = URI::encode "/#{database}/_design/#{design_doc}/_view/#{view}#{postfix}"
        res = get(uri)
        JSON.parse(res.body.force_encoding('utf-8'))['rows']
      end

      # If a block is given, performs the block for each +limit+-sized slice of rows for the given view.
      # If no block is given, returns all rows by appending +limit+-sized slices of the given view.
      def rows_for_view(db, design_doc, view, limit=500, opts={}, &block)
        get_all_views(lambda { |options| get_rows_for_view(db, design_doc, view, options) }, limit, opts, block)
      end


      # Returns an array of all ids in the database
      def get_all_ids(database, params)
        ids=[]
        postfix = create_postfix(params)

        uri = URI::encode "/#{database}/_all_docs#{postfix}"
        res = get(uri)
        result = JSON.parse(res.body)
        result['rows'].each do |row|
          if row['error']
            puts "#{row['key']}: #{row['error']}"
            puts "#{row['reason']}"
          else
            ids << row['id']
          end
        end
        ids
      end

      # Returns an array of all ids in the database
      def all_ids(db, limit=500, opts={}, &block)
        all_docs = []
        start_key = nil
        loop do
          opts = opts.merge({limit: limit})
          if start_key
            opts[:startkey]=start_key
          end
          docs = (lambda { |options| get_all_ids(db, options) }).call(opts)
          if docs.length <= 0
            break
          else
            if block
              block.call(docs)
            else
              all_docs < docs
            end
            start_key ="\"#{docs.last}\\ufff0\""
          end
        end
        all_docs.flatten
      end

      # Returns an array of the full documents for given view, possibly filtered with given parameters. Note that the 'include_docs' parameter must be set to true for this.
      #
      # Also consider using `docs_for_view`
      def get_docs_for_view(db, design_doc, view, params={})
        params.merge!({:include_docs => true})
        rows = get_rows_for_view(db, design_doc, view, params)
        docs = []
        rows.each do |row|
          docs << row['doc']
        end
        docs
      end

      # If a block is given, performs the block for each +limit+-sized slice of documents for the given view.
      # If no block is given, returns all docs by appending +limit+-sized slices of the given view.
      def docs_for_view(db, design_doc, view, limit=750, opts={}, &block)
        get_all_views(lambda { |options| get_docs_for_view(db, design_doc, view, options) }, limit, opts, block)
      end

      private

      def get_all_views(next_results, limit, opts, block)
        all = []
        offset = 0
        loop do
          opts = opts.merge({
                                limit: limit,
                                skip: offset,
                            })
          docs = next_results.call(opts)
          if docs.length <= 0
            break
          else
            if block
              block.call(docs)
            else
              all < docs
            end
            offset += limit
          end
        end
        all.flatten
      end

    end

    module Delete
      def bulk_delete(database, docs)
        docs.each do |doc|
          doc[:_deleted]=true
        end
        json = {:docs => docs}.to_json
        post("/#{database}/_bulk_docs", json)
      end
    end

    module Post
      # Flushes the given hashes to CouchDB
      def post_bulk(database, docs)
        body = {:docs => docs}.to_json #.force_encoding('utf-8')
        post("/#{database}/_bulk_docs", body)
      end

      def post_bulk_throttled(db, docs, &block)
        # puts "Flushing #{docs.length} docs"
        bulk = []
        docs.each do |doc|
          bulk << doc
          if bulk.to_json.bytesize/1024/1024 > options[:flush_size_mb] or bulk.length >= options[:max_array_length]
            handle_bulk_flush(bulk, db, block)
          end
        end
        if bulk.length > 0
          handle_bulk_flush(bulk, db, block)
        end
      end


      def post_bulk_if_big_enough(db, docs)
        flush = (docs.to_json.bytesize / 1024 >= (options[:flush_size_mb]*1024) or docs.length >= options[:max_array_length])
        if flush
          post_bulk_throttled(db, docs)
          docs.clear
        end
        flush
      end

      private

      def handle_bulk_flush(bulk, db, block)
        res = post_bulk(db, bulk)
        error_count=0
        if res.body
          begin
            JSON.parse(res.body).each do |d|
              error_count+=1 if d['error']
            end
          end
        end
        if error_count > 0
          puts "Bulk request completed with #{error_count} errors"
        end
        if block
          block.call(res)
        end
        bulk.clear
      end
    end
  end

  class Server
    attr_accessor :options

    def initialize(url, options)
      if url.is_a? String
        url = URI(url)
      end
      @couch_url = url
      @options = options
      @options[:couch_url] = @couch_url
      @options[:use_ssl] ||= true
      @options[:max_array_length] ||= 250
      @options[:flush_size_mb] ||= 10
      @options[:open_timeout] ||= 5*30
      @options[:read_timeout] ||= 5*30
      @options[:fail_silent] ||= false
    end

    def delete(uri)
      Request.new(Net::HTTP::Delete.new(uri), nil,
                  @options
      ).perform
    end

    def new_delete(uri)
      Request.new(Net::HTTP::Delete.new(uri)).couch_url(@couch_url)
    end

    def head(uri)
      Request.new(Net::HTTP::Head.new(uri), nil,
                  @options
      ).perform
    end

    def new_head(uri)
      Request.new(Net::HTTP::Head.new(uri)).couch_url(@couch_url)
    end

    def get(uri)
      Request.new(
          Net::HTTP::Get.new(uri), nil,
          @options
      ).perform
    end

    def new_get(uri)
      Request.new(Net::HTTP::Get.new(uri)).couch_url(@couch_url)
    end

    def put(uri, json)
      Request.new(Net::HTTP::Put.new(uri), json,
                  @options
      ).perform
    end

    def new_put(uri)
      Request.new(Net::HTTP::Put.new(uri)).couch_url(@couch_url)
    end

    def post(uri, json)
      Request.new(Net::HTTP::Post.new(uri), json,
                  @options
      ).perform
    end

    def new_post(uri)
      Request.new(Net::HTTP::Post.new(uri)).couch_url(@couch_url)
    end

    class Request
      def initialize(req, json=nil, opts={open_timeout: 5*30, read_timeout: 5*30, fail_silent: false})
        @req=req
        @json = json
        @options = opts
      end

      def json(json)
        @json = json
        self
      end

      def couch_url(couch_url)
        @options.merge!({couch_url: couch_url})
        self
      end

      def open_timeout(open_timeout)
        @options.merge!({open_timeout: open_timeout})
        self
      end

      def read_timeout(read_timeout)
        @options.merge!({read_timeout: read_timeout})
        self
      end

      def fail_silent(fail_silent)
        @options.merge!({fail_silent: fail_silent})
        self
      end

      def perform
        @req.basic_auth @options[:name], @options[:password]

        if @json
          @req['Content-Type'] = 'application/json;charset=utf-8'
          @req.body = @json
        end

        res = Net::HTTP.start(
            @options[:couch_url].host,
            @options[:couch_url].port,
            {:use_ssl => @options[:couch_url].scheme =='https'}
        ) do |http|
          http.open_timeout = @options[:open_timeout]
          http.read_timeout = @options[:read_timeout]
          http.request(@req)
        end

        unless @options[:fail_silent] or res.kind_of?(Net::HTTPSuccess)
          # puts "CouchDb responsed with error code #{res.code}"
          handle_error(@req, res)
        end
        res
      end

      def handle_error(req, res)
        raise RuntimeError.new("#{res.code}:#{res.message}\nMETHOD:#{req.method}\nURI:#{req.path}\n#{res.body}")
      end
    end

    include BasicRequest
    include BasicRequest::Head
    include BasicRequest::Get
    include BulkRequest::Get
    include BulkRequest::Delete
    include BulkRequest::Post

    private
  end
end
