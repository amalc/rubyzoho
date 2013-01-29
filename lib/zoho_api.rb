require 'httparty'
require '../lib/ruby_zoho'
require 'rexml/document'
require 'yaml'

module ZohoApi

  class Crm
    include HTTParty

    #debug_output $stderr

    attr_reader :auth_token

    def initialize(config_file_path)
      @config_file_path = config_file_path
      raise('Zoho configuration file not found', RuntimeError, config_file_path) unless
          File.exist?(config_file_path)
      @params = YAML.load(File.open(config_file_path))
      @auth_token = @params['auth_token']
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def contacts
      r = self.class.get(create_url('Contacts', "getRecords"),
        :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi' })
      return r.body if r.response.code == "200" && r.body.index('4422').ni?
      nil
    end

    def find_contact_by_email(email)
      r = self.class.get(create_url('Contacts', "getSearchRecords"),
        :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
        :selectColumns => "Contacts(First Name,Last Name,Email,Company)",
        :searchCondition => "(Email|=|#{email})" })
        return r.body if r.response.code == "200" && r.body.index("4422").nil?
      nil
    end

    def leads
      r = self.class.get(create_url('Leads', "getRecords"),
        :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi' })
      return r.body if r.response.code == "200"
      nil
    end

    def lead=
      response = get(create_url('Leads', "getRecords"), :body =>
         {:newFormat => '1', :authtoken => @auth_token, :scope => 'crmapi', :xmlData => xml_data})
    end

    def string_to_method_name(s)
      s.gsub(' ', '_').downcase
    end

    def string_to_symbol(s)
      s.gsub(' ', '_').downcase.to_sym
    end

    def xml_to_ruby(xml_document)
      doc = REXML::Document.new(xml_document)
      pp doc.root.attributes['uri']
      unless REXML::XPath.first(doc, "//Contacts").nil?
        contact = RubyZoho::Crm::Contact.new
        REXML::XPath.each(doc, "//FL") { |e| "#{string_to_method_name(e.attribute('val').to_s)}" }
        #REXML::XPath.each(doc, "//FL") { |e| puts "#{string_to_symbol(e.attribute('val').to_s)} => \"#{e.text}\""}
      end
    end
  end

end
