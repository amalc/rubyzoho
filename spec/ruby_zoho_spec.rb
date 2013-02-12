$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'

describe RubyZoho::Crm::Contact do

  before(:all) do
    base_path = File.join(File.dirname(__FILE__), 'fixtures')
    config_file = File.join(base_path, 'zoho_api_configuration.yaml')
    #params = YAML.load(File.open(config_file))
    RubyZoho.configure do |config|
      #config.api_key = params['auth_token']
      config.api_key = '62cedfe9427caef8afb9ea3b5bf68154'
    end
  end

  it 'should add accessors using a list of names' do
    c = RubyZoho::Crm::Contact.new
    c.first_name = 'Raj'
    c.first_name.should eq('Raj')
    c.email = 'raj@portra.com'
    c.email.should eq('raj@portra.com')
  end

  it 'should find a contact by email or last name' do
    1.upto(3) do
      c = RubyZoho::Crm::Contact.new(
        :first_name => 'Bob',
        :last_name => 'Smithereens',
        :email => 'bob@smith.com')
      c.save
    end
  r = RubyZoho::Crm::Contact.find_by_email('bob@smith.com')
    r.should_not eq(nil)
    r.count.should eq(3)
    r.each { |m| m.email.should eq('bob@smith.com') }
    r = RubyZoho::Crm::Contact.find_by_last_name('Smithereens')
    r.should_not eq(nil)
    r.first.last_name.should eq('Smithereens')
    r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) }
  end

  it 'should get a list of attr_writers for accounts' do
    c = RubyZoho::Crm::Account.new
    c.attr_writers.count.should be >= 34
  end

  it 'should get a list of attr_writers for contacts' do
    c = RubyZoho::Crm::Contact.new
    c.attr_writers.count.should be >= 43
  end

  it 'should get a list of attr_writers for leads' do
    c = RubyZoho::Crm::Lead.new
    c.attr_writers.count.should be >= 34
  end

  it 'should get a list of attr_writers for potentials' do
    c = RubyZoho::Crm::Potential.new
    c.attr_writers.count.should be >= 26
  end

  it 'should get a list of attr_writers for quotes' do
    c = RubyZoho::Crm::Quote.new
    c.attr_writers.count.should be >= 33
  end

  it 'should get a list of contacts' do
    RubyZoho::Crm::Contact.all.count.should be > 1
  end

  it 'should save a record' do
    c = RubyZoho::Crm::Contact.new
    c.first_name = 'Raj'
    c.last_name = 'Portra'
    c.email = 'raj@portra.com'
    c.save
  end

end