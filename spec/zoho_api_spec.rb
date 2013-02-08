$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require "spec_helper"
require "zoho_api"
require "xmlsimple"

describe ZohoApi do

  before(:all) do
    base_path = File.join(File.dirname(__FILE__), "fixtures")
    @config_file = File.join(base_path, "zoho_api_configuration.yaml")
    @zoho = ZohoApi::Crm.new(@config_file)
    @email_address = 'jane@smith.com'
    @sample_contact_xml = File.join(base_path, 'sample_contact.xml')
    @sample_contact_search_xml = File.join(base_path, 'sample_contact_search.xml')
    @sample_contacts_xml = File.join(base_path, 'sample_contacts_list.xml')
  end

  it "should add accessors using a list of names" do
    doc = File.read(@sample_contact_xml)
    r = @zoho.records_to_array(doc)
    ZohoApi::Crm.create_accessor(r[0].keys)
    z = ZohoApi::Crm.new(@config_file)
    z.first_name= 'Raj'
    z.first_name.should eq('Raj')
  end

  it "should add a new contact" do
    pending
    h = { :first_name => 'Robert',
          :last_name => 'Smith',
          :email => 'rsmith@smithereens.com',
          :department => 'Waste Collection and Management',
          :phone => '13452129087',
          :mobile => '12341238790'
    }
    c = RubyZoho::Crm::Contact.new
    r = @zoho.add_contact(c)
    r.should eq(h)
    contact = @zoho.find_contact_by_email(h[:email])
    contact.should_not eq(nil)
  end

  it "should convert many zoho records to an array of hashes" do
    doc = File.read(@sample_contacts_xml)
    r = @zoho.records_to_array(doc)
    r.count.should be == 7
  end

  it "should convert one zoho record to an array of one hash" do
    doc = File.read(@sample_contact_xml)
    r = @zoho.records_to_array(doc)
    r.count.should be == 1
  end

  it "should find a contact by email address" do
    contact = @zoho.find_contact_by_email(@email_address)
    contact.should_not eq(nil)
  end

  it "should get a list of contacts" do
    contacts = @zoho.contacts
    contacts.should_not eq(nil)
    r =  XmlSimple.xml_in(contacts)
    r['uri'].should eq('/crm/private/xml/Contacts/getRecords')
  end

  it "should get a list of leads" do
    leads = @zoho.leads
    leads.should_not eq(nil)
    r =  XmlSimple.xml_in(leads)
    r['uri'].should eq('/crm/private/xml/Leads/getRecords')
  end

  it "should convert an XML result to a Ruby object" do
    xml = File.read(@sample_contact_search_xml)
    @zoho.xml_to_ruby(xml)
  end

  it "should return a list of fields for a contact" do
    r = @zoho.contact_fields
    #f = File.new('sample_contact.xml', 'w+')
    #f.write(r)
    #f.close
    r.should_not eq(nil)
    xml = REXML::Document.new(r)
    REXML::XPath.each(xml, '//FL').count.should eq(336)
  end

end
