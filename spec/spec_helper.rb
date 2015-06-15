require 'codeclimate-test-reporter'
# noinspection RubyResolve
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib',
                                    __FILE__)
require 'couch/db/version'
require 'couch/db'

