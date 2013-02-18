$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'

describe RubyZoho::Crm do

  before(:all) do
    base_path = File.join(File.dirname(__FILE__), 'fixtures')
    config_file = File.join(base_path, 'zoho_api_configuration.yaml')
    #params = YAML.load(File.open(config_file))
    RubyZoho.configure do |config|
      #config.api_key = params['auth_token']
      #config.api_key = 'e194b2951fb238e26bc096de9d0cf5f8'
      config.api_key = '62cedfe9427caef8afb9ea3b5bf68154'
      config.crm_modules = %w(Quotes)
    end
    #r = RubyZoho::Crm::Contact.find_by_last_name('Smithereens')
    #r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) } unless r.nil?
    #r = RubyZoho::Crm::Contact.find_by_email('raj@portra.com')
    #r.each { |c|  RubyZoho::Crm::Contact.delete(c.contactid) } unless r.nil?
  end

  it 'should add accessors using a list of names' do
    c = RubyZoho::Crm::Contact.new
    c.first_name = 'Raj'
    c.first_name.should eq('Raj')
    c.email = 'raj@portra.com'
    c.email.should eq('raj@portra.com')
  end

  it 'should find a contact by email or last name' do
    r = RubyZoho::Crm::Contact.find_by_email('bob@smith.com')
    r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) } unless r.nil?
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
    r.map { |c| c.last_name }.count.should eq(3)
    r.first.last_name.should eq('Smithereens')
    r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) }
  end

  it 'should find a contact by ID' do
    contacts = RubyZoho::Crm::Contact.all
    contact_id = contacts.first.contactid
    c = RubyZoho::Crm::Contact.find_by_contactid(contact_id)
    c.first.contactid.should eq(contact_id)
    c.first.last_name.should eq(contacts.first.last_name)
    c.first.email.should eq(contacts.first.email)
  end

  it 'should find a lead by ID' do
    leads = RubyZoho::Crm::Lead.all
    lead_id = leads.first.leadid
    l = RubyZoho::Crm::Lead.find_by_leadid(lead_id)
    l.first.leadid.should eq(lead_id)
  end

  it 'should find a user by email address' do
    users = RubyZoho::Crm::User.all
    r = RubyZoho::Crm::User.find_by_email(users.first.email)
    r.first.email.should eq(users.first.email)
  end

  it 'should get a list of attr_writers for accounts' do
    c = RubyZoho::Crm::Account.new
    c.attr_writers.count.should be >= 18
  end

  it 'should get a list of attr_writers for contacts' do
    c = RubyZoho::Crm::Contact.new
    c.attr_writers.count.should be >= 21
  end

  it 'should get a list of attr_writers for leads' do
    c = RubyZoho::Crm::Lead.new
    c.attr_writers.count.should be >= 16
  end

  it 'should get a list of attr_writers for potentials' do
    c = RubyZoho::Crm::Potential.new
    c.attr_writers.count.should be >= 14
  end

  it 'should get a list of attr_writers for quotes' do
    c = RubyZoho::Crm::Quote.new
    c.attr_writers.count.should be >= 18
  end

  it 'should get a list of accounts' do
    r = RubyZoho::Crm::Account.all
    r.count.should be > 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Account) }
  end

  it 'should get a list of contacts' do
    r = RubyZoho::Crm::Contact.all
    r.count.should be > 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Contact) }
  end

  it 'should get a list of events' do
    r = RubyZoho::Crm::Event.all
    r.count.should be > 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Event) }
  end

  it 'should get a list of potentials' do
    r = RubyZoho::Crm::Potential.all
    r.count.should be > 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Potential) }
  end

  it 'should get a list of quotes' do
    r = RubyZoho::Crm::Quote.all
    r.count.should be >= 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Quote) }
  end

  it 'should get a list of tasks' do
    r = RubyZoho::Crm::Task.all
    r.count.should be > 1
    r.map { |r| r.class.should eq(RubyZoho::Crm::Task) }
  end

  it 'should get a list of users' do
    r = RubyZoho::Crm::User.all
    r.count.should be >= 1
  end

  it 'should save a contact record' do
    c = RubyZoho::Crm::Contact.new(
      :first_name => 'Raj',
      :last_name => 'Portra',
      :email => 'raj@portra.com')
    c.save
    r = RubyZoho::Crm::Contact.find_by_email('raj@portra.com')
    r.first.email.should eq('raj@portra.com')
    r.each { |c|  RubyZoho::Crm::Contact.delete(c.contactid) }
  end

  it 'should sort contact records' do
    r = RubyZoho::Crm::Contact.all
    sorted =  r.sort {|a, b| a.last_name <=> b.last_name }
    sorted.collect { |c| c.last_name }.should_not eq(nil)
  end

  it 'should save a lead record' do
    l = RubyZoho::Crm::Lead.new(
      :first_name => 'Raj',
      :last_name => 'Portra',
      :email => 'raj@portra.com')
    l.save
    r = RubyZoho::Crm::Lead.find_by_email('raj@portra.com')
    r.should_not eq(nil)
    r.first.email.should eq(l.email)
    r.each { |c|  RubyZoho::Crm::Lead.delete(c.leadid) }
  end

  it 'should save a potential record' do
    accounts = RubyZoho::Crm::Account.all
    p = RubyZoho::Crm::Potential.new(
        :potential_name => 'A very big potential INDEED!!!!!!!!!!!!!',
        :accountid => accounts.first.accountid,
        :account_name => accounts.first.account_name,
        :closing_date => '1/1/2014',
        :type => 'New Business',
        :stage => 'Needs Analysis')
    p.save
    r = RubyZoho::Crm::Potential.find_by_potential_name(p.potential_name)
    r.first.potential_name.should eq('A very big potential INDEED!!!!!!!!!!!!!')
    r.each { |c|  RubyZoho::Crm::Potential.delete(c.potentialid) }
  end

  it 'should update a lead record' do
    l = RubyZoho::Crm::Lead.new(
      :first_name => 'Raj',
      :last_name => 'Portra',
      :email => 'raj@portra.com')
    l.save
    r = RubyZoho::Crm::Lead.find_by_email('raj@portra.com')
    RubyZoho::Crm::Lead.update(
        :id => r.first.leadid,
        :email => 'changed_raj@portra.com'
    )
    r_changed = RubyZoho::Crm::Lead.find_by_email('changed_raj@portra.com')
    r.first.leadid.should eq(r_changed.first.leadid)
    r_changed.should_not eq(nil)
    r.each { |c|  RubyZoho::Crm::Lead.delete(c.leadid) }
  end

  it 'should validate a field name' do
    good_names = ['This is OK', 'OK_to_use']
    bad_names = ['This % is not', 'Bad()']
    good_names.map { |f| RubyZoho::Crm.method_name?(ApiUtils.string_to_symbol(f)).should_not eq(false)}
    bad_names.map { |f| RubyZoho::Crm.method_name?(ApiUtils.string_to_symbol(f)).should eq(false)}
  end

end