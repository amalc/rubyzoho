require 'zoho_api'
require 'api_utils'


module RubyZoho

  class Configuration
    attr_accessor :api, :api_key, :crm_modules

    def initialize
      self.api_key = nil
      self.api = nil
      self.crm_modules = nil
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    self.configuration.crm_modules ||= ['Accounts', 'Contacts', 'Leads', 'Potentials']
    self.configuration.api = ZohoApi::Crm.new(self.configuration.api_key, self.configuration.crm_modules)
  end



  class Crm

    class << self
      attr_accessor :module_name
    end

    def initialize(object_attribute_hash = {})
      @fields = RubyZoho.configuration.api.module_fields[
          ApiUtils.string_to_symbol(Crm.module_name)]
      RubyZoho::Crm.create_accessor(self.class, @fields)
      object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
    end

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

    def create(object_attribute_hash)
      initialize(object_attribute_hash)
      save
    end

    def save
      h = {}
      @fields.each { |f| h.merge!({ f => eval("self.#{f.to_s}") }) }
      RubyZoho.configuration.api.add_record(Crm.module_name, h)
    end

    def self.all         #TODO Refactor into low level API
      result = []
      i = 1
      begin
        batch = RubyZoho.configuration.api.some(Crm.module_name, i, 200)
        i += 200
        result.concat(batch) unless batch.nil?
      end while !batch.nil?
      result.collect { |r| new(r) }
    end

    def self.delete(id)
      RubyZoho.configuration.api.delete_record(Crm.module_name, id)
    end

    def self.method_missing(meth, *args, &block)
      if meth.to_s =~ /^find_by_(.+)$/
        run_find_by_method($1, *args, &block)
      else
        super
      end
    end

    def self.run_find_by_method(attrs, *args, &block)
      attrs = attrs.split('_and_')
      conditions = Array.new(args.size, '=')
      h = RubyZoho.configuration.api.find_records(
          Crm.module_name, ApiUtils.string_to_symbol(attrs[0]), conditions[0], args[0]
      )
      return h.collect { |r| new(r) } unless h.nil?
      nil
    end

    def self.update(object_attribute_hash)
      raise(RuntimeError, 'No ID found', object_attribute_hash) if object_attribute_hash[:id].nil?
      id = object_attribute_hash[:id]
      object_attribute_hash.delete(:id)
      RubyZoho.configuration.api.update_record(Crm.module_name, id, object_attribute_hash)
    end


    class Account < RubyZoho::Crm
      include RubyZoho
      attr_reader :fields
      Crm.module_name = 'Accounts'

      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Accounts'
        super
      end

      def self.all
        Crm.module_name = 'Accounts'
        super
      end

      def self.delete(id)
        Crm.module_name = 'Accounts'
        super
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Accounts'
        super
      end
    end


    class Contact < RubyZoho::Crm
      include RubyZoho
      attr_reader :fields
      Crm.module_name = 'Contacts'

      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Contacts'
        super
      end

      def self.all
        Crm.module_name = 'Contacts'
        super
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Contacts'
        super
      end

      def self.delete(id)
        Crm.module_name = 'Contacts'
        super
      end
    end


    class Lead < RubyZoho::Crm
      include RubyZoho
      attr_reader :fields
      Crm.module_name = 'Leads'

      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Leads'
        super
      end

      def self.all
        Crm.module_name = 'Leads'
        super
      end

      def self.delete(id)
        Crm.module_name = 'Leads'
        super
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Leads'
        super
      end
    end

    class Potential < RubyZoho::Crm
      include RubyZoho
      attr_reader :fields
      Crm.module_name = 'Potentials'

      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Potentials'
        super
      end

      def self.all
        Crm.module_name = 'Potentials'
        super
      end

      def self.delete(id)
        Crm.module_name = 'Potentials'
        super
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Potentials'
        super
      end
    end

    class Quote < RubyZoho::Crm
      include RubyZoho
      attr_reader :fields
      Crm.module_name = 'Quotes'

      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Quotes'
        super
      end

      def self.all
        Crm.module_name = 'Quotes'
        super
      end

      def self.delete(id)
        Crm.module_name = 'Quotes'
        super
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Quotes'
        super
      end
    end

  end

end
