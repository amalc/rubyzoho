require "spec_helper"
require "../lib/zoho_crm"
require "xmlsimple"

describe ZohoCrm do


  before(:all) do
    @config_file = "../spec/fixtures/zoho_api_configuration.yaml"
    @z = ZohoCrm.new(@config_file)
  end

  it "should get a list of contacts" do
    contacts = @z.contacts
    contacts.should_not eq(nil)
    r =  XmlSimple.xml_in(contacts)
    f = File.new('sample_contacts.xml', 'w+')
    f.write(contacts)
    f.close

    r['uri'].should eq('/crm/private/xml/Contacts/getRecords')
  end

  it "should get a list of leads" do
    leads = @z.leads
    leads.should_not eq(nil)
    r =  XmlSimple.xml_in(leads)
    r['uri'].should eq('/crm/private/xml/Leads/getRecords')
  end

end
