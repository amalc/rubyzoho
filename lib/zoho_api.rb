$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'httparty'
require 'rexml/document'
require 'ruby_zoho'
require 'yaml'
require 'api_utils'

module ZohoApi

  include ApiUtils

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

    def self.create_accessor(names)
      names.each do |n|
        create_getter(n)
        create_setter(n)
      end
    end

    def self.create_getter(*names)
        names.each do |name|
          define_method("#{name}") { instance_variable_get("@#{name}") }
        end
      names
    end

    def self.create_method(name, &block)
      self.class.send(:define_method, name, &block)
    end

    def self.create_setter(*names)
        names.each do |name|
            define_method("#{name}=") { |val| instance_variable_set("@#{name}", val) }
        end
      names
    end

    def add_contact(c)
      return nil unless c.class == RubyZoho::Crm::Contact
      x = REXML::Document.new
      contacts = x.add_element 'Contacts'
      row = contacts.add_element 'Row', { 'no' => '1'}
      pp c.methods.grep(/\w=$/)
      pp x.to_s
      c
    end

    def add_dummy_contact
      x = REXML::Document.new
      contacts = x.add_element 'Contacts'
      row = contacts.add_element 'row', { 'no' => '1'}
      r1 = (REXML::Element.new 'FL')
      r1.attributes['val'] = 'First Name'
      r1.add_text('BobDifficultToMatch')
      row.elements << r1
      r2 = (REXML::Element.new 'FL')
      r2.attributes['val'] = 'Last Name'
      r2.add_text('SmithbDifficultToMatch')
      row.elements << r2
      #r3 = (REXML::Element.new 'FL')
      #r3.attributes['val'] = 'SMOWNERID'
      #r3.add_text('achaudhuri@bondfactor.com')
      #row.elements << r3
      r4 = (REXML::Element.new 'FL')
      r4.attributes['val'] = 'Email'
      r4.add_text('bob@smith.com')
      row.elements << r4
      pp xml_data = x.to_s
      r = self.class.post(create_url('Contacts', "insertRecords"),
        :query => { :newFormat => 1, :authtoken => @auth_token,
        :scope => 'crmapi', :xmlData => xml_data },
        :headers => { "Content-length" => "0" })
      pp r.response.code
      pp r.response.body.to_s
      raise("Adding contact failed", RuntimeError, r.response.body.to_s) unless r.response.code == '200'
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def contact_fields
      r = self.class.get(create_url('Contacts', "getRecords"),
        :query => { :newFormat => 2, :authtoken => @auth_token,
        :scope => 'crmapi', :toIndex => 1 })
      return r.body if r.response.code == "200" && r.body.index('4422').nil?
      nil
    end

    def contacts
      r = self.class.get(create_url('Contacts', "getRecords"),
        :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi' })
      return r.body if r.response.code == "200" && r.body.index('4422').nil?
      nil
    end

    def find_contact_by_email(email)
      r = self.class.get(create_url('Contacts', "getSearchRecords"),
        :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
        :selectColumns => "Contacts(First Name,Last Name,Email,Company)",
        :searchCondition => "(Email|=|#{email})" })
        return r.body if r.response.code == "200" && r.body.index("4422").nil?
      nil
    end

    def leads
      r = self.class.get(create_url('Leads', "getRecords"),
        :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi' })
      return r.body if r.response.code == "200"
      nil
    end

    def lead=(lead_data)
      xml_data = lead_data
      response = get(create_url('Leads', "getRecords"), :body =>
         {:newFormat => '1', :authtoken => @auth_token, :scope => 'crmapi', :xmlData => xml_data})
      response.body
    end

    def record_to_hash(doc)
      ZohoApi::Crm.record_to_h(doc)
    end

    def self.record_to_h(doc)
      r = []
      REXML::XPath.each(doc, "FL") { |e| r << [ApiUtils.string_to_method_name(e.attribute('val').to_s), e.text] }
      Hash[r]
    end

    def records_to_array(xml_doc)
      ZohoApi::Crm.records_to_a(xml_doc)
    end

    def self.records_to_a(xml_doc)
      result = []
      doc = REXML::Document.new(xml_doc)
      REXML::XPath.each(doc, "/response/result/Contacts/row").each do |r|
        result << record_to_h(r)
      end
      result
    end

    def xml_to_ruby(xml_document)
      doc = REXML::Document.new(xml_document)
      doc.root.attributes['uri']
      unless REXML::XPath.first(doc, "//Contacts").nil?
        contact = RubyZoho::Crm::Contact.new
        REXML::XPath.each(doc, "//FL") { |e| "#{ApiUtils.string_to_method_name(e.attribute('val').to_s)}" }
        #REXML::XPath.each(doc, "//FL") { |e| puts "#{string_to_symbol(e.attribute('val').to_s)} => \"#{e.text}\""}
      end
    end
  end

end
