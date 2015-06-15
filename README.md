# Ruby CouchDB
[![Build Status](https://travis-ci.org/digitalheir/couch-request.svg)](https://travis-ci.org/digitalheir/couch-request)
[![Code Climate](https://codeclimate.com/repos/557eed7de30ba02ffe010520/badges/11baa9055d509aedf45d/gpa.svg)](https://codeclimate.com/repos/557eed7de30ba02ffe010520/feed)
[![Test Coverage](https://codeclimate.com/repos/557eed7de30ba02ffe010520/badges/11baa9055d509aedf45d/coverage.svg)](https://codeclimate.com/repos/557eed7de30ba02ffe010520/coverage)

Ruby gem to connect to a CouchDB database in Ruby, focusing on bulk requests. Make sure to watch Tim Anglade's excellent talk **[CouchDB & Ruby: You're Doing It Wrong](https://www.youtube.com/watch?v=zEMfvCqVL4E)**.
 
<center>
<a href="http://www.youtube.com/watch?feature=player_embedded&v=zEMfvCqVL4E
" target="_blank"><img src="https://img.youtube.com/vi/zEMfvCqVL4E/0.jpg" 
alt="CouchDB & Ruby: You're Doing It Wrong by Tim Anglade" width="240" height="180" border="10" /></a>
</center>

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'couch-db'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install couch-db

## Usage

```ruby

    require 'couch/db'
    
    # Subclass Couch::Server for application-specific logic
    class MyCouch < Couch::Server
      DB_NAME = 'my-db'
    
      def initialize
        super(
            'https://user.couchprovider.com/', # The library automatically detects whether to use SSL
            {
                name: 'user',
                password: 'supersecretpassword' # May be nil for public databases 
            }
        )
        @queue = []
      end
  
      def add_to_queue(doc, max_array_length: 3)
        @queue << doc
        flushed = post_bulk_if_big_enough(DB_NAME, @queue, max_array_length: max_array_length)
        puts "Added #{doc[:_id]} to queue. Flushed: #{flushed}"
      end
    
      def flush_queue
        length = @queue.length
        post_bulk_throttled(DB_NAME, @queue) do |res|
          puts "Flushed bulk, response code #{res.code}"
        end
        length
      end
    end
    
    #####################
    # Script starts here 
    #####################
    
    # Initialize couch interface
    couch = MyCouch.new
    couch.put("/#{MyCouch::DB_NAME}",'') # Create database
    
    # Add some documents to our database, triggering a bulk post after every 3 docs
    (1..11).each do |i|
      couch.add_to_queue({_id: "document-#{i}"})
    end
    
    # Get single document. 
    puts couch.get_doc(
                       'document-7', 
                       {stale: 'ok'} # Pass URL parameters in a hash
                      )
    
    # Flush remaining docs
    l = couch.flush_queue
    puts "Flushed remaining #{l} docs in queue"
    
    # Access docs
    couch.all_docs(MyCouch::DB_NAME, 4) do |slice|
      puts "> Next #{slice.length} docs:"
      slice.each do |doc|
        puts doc
      end
    end 
    
    # Delete database
    couch.delete("/#{MyCouch::DB_NAME}") 

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/digitalheir/ruby-couch-db. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

