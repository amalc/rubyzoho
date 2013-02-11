require 'zoho_api'
require 'api_utils'

module RubyZoho

  module Crm

    def attr_writers
      self.methods.grep(/\w=$/)
    end

    def self.create_accessor(klass, names)
      names.each do |name|
        n = name
        n = name.to_s if name.class == Symbol
        create_getter(klass, n)
        create_setter(klass, n)
      end
      names
    end

    def self.create_getter(klass, *names)
      names.each do |name|
        klass.send(:define_method, "#{name}") { instance_variable_get("@#{name}") }
      end
    end

    def self.create_setter(klass, *names)
      names.each do |name|
        klass.send(:define_method, "#{name}=") { |val| instance_variable_set("@#{name}", val) }
      end
    end

    class Contact
      include RubyZoho::Crm

      attr_reader :fields

      def initialize(api, object_attribute_hash = {})
        @module_name = 'Contacts'
        @api = api
        @fields = api.module_fields[:contacts]
        RubyZoho::Crm.create_accessor(RubyZoho::Crm::Contact, @fields)
        object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
      end

      def create(api, object_attribute_hash)
        initialize(api, object_attribute_hash)
        save
      end

      def delete(id)
        @api.delete_record(@module_name, id)
      end

      def save
        h = {}
        @fields.each { |f| h.merge!({ f => eval("self.#{f.to_s}")}) }
        @api.add_record(@module_name, h)
      end

    end

    class Lead

    end

  end

end
