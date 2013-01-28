require "spec_helper"
require "../lib/zoho_crm"
require "xmlsimple"

describe ZohoCrm do


  before(:all) do
    @config_file = "../spec/fixtures/zoho_api_configuration.yaml"
    @z = ZohoCrm.new(@config_file)
  end

  it "should get a list of leads" do
    leads = @z.leads
    r =  XmlSimple.xml_in(leads)
    leads.should_not eq(nil)
    pp r['head'][0]['title'].should_not eq(["400 - Bad Request"])
  end
end