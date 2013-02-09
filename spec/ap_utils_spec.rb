$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require "spec_helper"
require "../lib/api_utils"

describe ApiUtils do

  it "should camelize a method name" do
    ApiUtils.camelize_with_space('method_name').should eq('Method Name')
  end

  it "should convert a string to a method name" do
    ApiUtils.string_to_method_name('First  Name').should eq('first__name')
    ApiUtils.string_to_method_name('First name').should eq('first_name')
    ApiUtils.string_to_method_name('last Name').should eq('last_name')
    ApiUtils.string_to_method_name('FirstName').should eq('firstname')
    ApiUtils.string_to_method_name('first name').should eq('first_name')
  end

  it "should convert a string to symbol" do
    ApiUtils.string_to_symbol('First  Name').should eq(:first__name)
    ApiUtils.string_to_symbol('First Name').should eq(:first_name)
    ApiUtils.string_to_symbol('Last Name').should eq(:last_name)
  end
end