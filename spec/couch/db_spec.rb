# noinspection RubyResolve
require 'spec_helper'


TEST_DB="test_#{RUBY_VERSION}"

# require 'json'

describe Couch do
  couch = nil
  it 'can initialize a Couch server' do
    expect(ENV['COUCH_TEST_URL']).not_to be nil
    expect(ENV['COUCH_TEST_NAME']).not_to be nil
    expect(ENV['COUCH_TEST_PASSWORD']).not_to be nil
    couch = Couch::Server.new(
        ENV['COUCH_TEST_URL'],
        {
            name: ENV['COUCH_TEST_NAME'],
            password: ENV['COUCH_TEST_PASSWORD'],
        }
    )
    expect(couch).not_to be nil
  end

  it 'can create test db' do
    couch.put("/#{TEST_DB}", '')
  end

  it 'can create documents' do
    i=0
    couch.post_bulk_throttled(TEST_DB, [
                                         {_id: 'hello1'},
                                         {_id: 'hello2'},
                                         {_id: 'hello3'},
                                         {_id: 'hello4'},
                                     ],
                              max_array_length: 2) do |res|
      expect(res.kind_of?(Net::HTTPSuccess)).to eq(true)
      i+=1
    end
    expect(i).to eq(2)
  end

  it 'can request a single document' do
    doc = couch.get_doc(TEST_DB, 'hello1')
    expect(doc['_id']).to eq('hello1')
  end

  it 'can request all documents' do
    i = 1
    couch.all_docs(TEST_DB, 2) do |slice|
      slice.each do |doc|
        expect(doc['_id']).to eq("hello#{i}")
        i+=1
      end
    end

    i = 1
    couch.all_ids(TEST_DB, 2) do |slice|
      slice.each do |id|
        expect(id).to eq("hello#{i}")
        i+=1
      end
    end
  end

  it 'can delete database' do
    couch.delete("/#{TEST_DB}")
  end
end
