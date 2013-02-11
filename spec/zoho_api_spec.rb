$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'
require 'xmlsimple'

describe ZohoApi do

  def add_dummy_contact
    c = {:first_name => 'BobDifficultToMatch', :last_name => 'SmithDifficultToMatch',
         :email => 'bob@smith.com'}
    @zoho.add_record('Contacts', c)
  end

  def delete_dummy_contact
    c = @zoho.find_record(
        'Contacts', :email, 'bob@smith.com')
    @zoho.delete_record('Contacts', c[0][:contactid]) unless c == []
  end


  before(:all) do
    base_path = File.join(File.dirname(__FILE__), 'fixtures')
    @config_file = File.join(base_path, 'zoho_api_configuration.yaml')
    @zoho = ZohoApi::Crm.new(@config_file)
    @email_address = 'jane@smith.com'
    @sample_contact_xml = File.join(base_path, 'sample_contact.xml')
    @sample_contact_search_xml = File.join(base_path, 'sample_contact_search.xml')
    @sample_contacts_xml = File.join(base_path, 'sample_contacts_list.xml')
  end

  it 'should add a new contact' do
    h = { :first_name => 'Robert',
          :last_name => 'Smith',
          :email => 'rsmith@smithereens.com',
          :department => 'Waste Collection and Management',
          :phone => '13452129087',
          :mobile => '12341238790'
    }
    @zoho.add_record('Contacts', h)
    contact = @zoho.find_record(
        'Contacts', :email, h[:email])
    @zoho.delete_record('Contacts', contact[0][:contactid])
    contact.should_not eq(nil)
    contact.count.should eq(1)
  end

  it 'should delete a contact record with id' do
    add_dummy_contact
    c = @zoho.find_record(
        'Contacts', :email, 'bob@smith.com')
    @zoho.delete_record('Contacts', c[0][:contactid])
  end

  it 'should find by module and field for columns' do
    add_dummy_contact
    r = @zoho.find_record(
        'Contacts', :email, 'bob@smith.com')
    r[0][:email].should eq('bob@smith.com')
    delete_dummy_contact
  end

  it 'should get a list of fields for a module' do
    r = @zoho.fields('Contacts')
    r.count.should eq(43)
    r = @zoho.fields('Leads')
    r.count.should eq(34)
  end

  it 'should retrieve records by module name' do
    r = @zoho.some('Contacts')
    r.should_not eq(nil)
    r[0][:email].should_not eq(nil)
    r.count.should be > 1
  end

end
