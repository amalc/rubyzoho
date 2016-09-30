$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'api_utils'

describe ApiUtils do

  it 'should camelize a method name' do
    ApiUtils.camelize_with_space('method_name').should eq('Method Name')
    ApiUtils.camelize_with_space('no_of_employees').should eq('No of Employees')
    ApiUtils.camelize_with_space('no_of_employees').should_not eq('No Of Employees')
  end

  it 'should convert a string to a method name' do
    ApiUtils.string_to_method_name('First  Name').should eq('first__name')
    ApiUtils.string_to_method_name('First name').should eq('first_name')
    ApiUtils.string_to_method_name('last Name').should eq('last_name')
    ApiUtils.string_to_method_name('FirstName').should eq('firstname')
    ApiUtils.string_to_method_name('first name').should eq('first_name')
  end

  it 'should convert a string to symbol' do
    ApiUtils.string_to_symbol('First  Name').should eq(:first__name)
    ApiUtils.string_to_symbol('First Name').should eq(:first_name)
    ApiUtils.string_to_symbol('Last Name').should eq(:last_name)
  end

  it 'should convert a symbol to a string' do
    ApiUtils.symbol_to_string(:first_name).should eq('First Name')
    ApiUtils.symbol_to_string(:constid).should eq('Constid')
    ApiUtils.symbol_to_string(:first).should eq('First')
    ApiUtils.symbol_to_string(:first_name_last).should eq('First Name Last')
  end

end
