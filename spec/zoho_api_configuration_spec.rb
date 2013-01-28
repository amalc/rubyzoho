require "../lib/ruby_zoho"
require "spec_helper"

describe ZohoApiConfiguration do

  it "should retrieve api parameters from YAML configuration file" do
    zoho = ZohoApiConfiguration.new("../spec/fixtures/zoho_api_configuration.yaml")
    zoho.params.should == {  }
  end

end