$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'

describe RubyZoho::Crm::Contact do

  before(:all) do
    base_path = File.join(File.dirname(__FILE__), 'fixtures')
    @config_file = File.join(base_path, 'zoho_api_configuration.yaml')
    @zoho = ZohoApi::Crm.new(@config_file)
  end

  it 'should add accessors using a list of names' do
    c = RubyZoho::Crm::Contact.new(@zoho)
    c.first_name = 'Raj'
    c.first_name.should eq('Raj')
    c.email = 'raj@portra.com'
    c.email.should eq('raj@portra.com')
  end

  it 'should get a list of attr_writers' do
    c = RubyZoho::Crm::Contact.new(@zoho)
    c.attr_writers.count.should be >= 43
  end

  it 'should get a list of contacts' do
    pending
    true.should == false
  end

  it 'should save a record' do
    c = RubyZoho::Crm::Contact.new(@zoho)
    c.first_name = 'Raj'
    c.last_name = 'Portra'
    c.email = 'raj@portra.com'
    c.save
  end

end