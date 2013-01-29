require "spec_helper"
require "../lib/zoho_api"
require "xmlsimple"

describe ZohoApi do


  before(:all) do
    base_path = "../spec/fixtures/"
    @config_file = "../spec/fixtures/zoho_api_configuration.yaml"
    @z = ZohoApi::Crm.new(@config_file)
    @email_address = 'jane@smith.com'
    @sample_contact_search_xml = base_path + 'sample_contact_search.xml'
  end

  it "should find a contact by email address" do
    contact = @z.find_contact_by_email(@email_address)
    contact.should_not eq(nil)
  end

  it "should get a list of contacts" do
    contacts = @z.contacts
    contacts.should_not eq(nil)
    r =  XmlSimple.xml_in(contacts)
    r['uri'].should eq('/crm/private/xml/Contacts/getRecords')
    f = File.new('sample_contacts_list.xml', 'w+')
    f.write(contacts)
    f.close
  end

  it "should get a list of leads" do
    leads = @z.leads
    leads.should_not eq(nil)
    r =  XmlSimple.xml_in(leads)
    r['uri'].should eq('/crm/private/xml/Leads/getRecords')
  end

  it "should convert a string to a symbol" do
    r = @z.string_to_symbol("Last Name")
    r.should eq(:last_name)
  end

  it "should convert an XML result to a Ruby object" do
    xml = File.read(@sample_contact_search_xml)
    @z.xml_to_ruby(xml)
  end

end
