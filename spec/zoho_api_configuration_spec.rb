require "../lib/ruby_zoho"
require "spec_helper"

describe ZohoApiConfiguration do

  before(:all) do
    @config_file = "../spec/fixtures/zoho_api_configuration.yaml"
  end


  it "should retrieve api parameters from YAML configuration file" do
    zoho = ZohoApiConfiguration.new(@config_file)
    zoho.should_not eq(nil)
    zoho.params.should == { "authtoken"=>"0bc4e131019d1a60936d5c7c85df6331" }
  end

end