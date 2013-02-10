#$:.unshift File.join('..', File.dirname(__FILE__), 'lib')
require 'zoho_api'

module RubyZoho
  module Crm

    class Contact

    attr_accessor :first_name, :last_name

      def initialize
        #base_path = File.join(File.dirname(__FILE__), "..", "spec", "fixtures")
        #@sample_contact_xml = File.join(base_path, 'sample_contact.xml')
        #doc = File.read(@sample_contact_xml)
        #r = ZohoApi::Crm.records_to_a(doc)
        #ZohoApi::Crm.create_accessor(r[0].keys)
      end

    end

    class Lead

    end

  end
end
