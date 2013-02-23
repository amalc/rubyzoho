$:.unshift File.join('..', File.dirname(__FILE__), 'lib')
require 'spec_helper'
require 'test_case'

describe TestCase do

  it 'should do something' do

  pp TestCase::Outer.module_name
  pp TestCase::Outer::Account.module_name
  pp TestCase::Outer::Account.new.module_name
  end
end