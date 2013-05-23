require 'zoho_api'
require 'api_utils'
require 'yaml'

module RubyZoho

  class Configuration
    attr_accessor :api, :api_key, :cache_fields, :crm_modules, :ignore_fields_with_bad_names

    def initialize
      self.api_key = nil
      self.api = nil
      self.cache_fields = false
      self.crm_modules = nil
      self.ignore_fields_with_bad_names = true
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    self.configuration.crm_modules ||= []
    self.configuration.crm_modules = %w[Accounts Calls Contacts Events Leads Potentials Tasks].concat(
        self.configuration.crm_modules).uniq
    self.configuration.api = init_api(self.configuration.api_key,
        self.configuration.crm_modules, self.configuration.cache_fields)
    RubyZoho::Crm.setup_classes()
  end

  def self.init_api(api_key, modules, cache_fields)
    base_path = File.join(File.dirname(__FILE__), '..', 'spec', 'fixtures')
    if File.exists?(File.join(base_path, 'fields.snapshot')) && cache_fields == true
      fields = YAML.load(File.read(File.join(base_path, 'fields.snapshot')))
      zoho = ZohoApi::Crm.new(api_key, modules,
          self.configuration.ignore_fields_with_bad_names, fields)
    else
      zoho = ZohoApi::Crm.new(api_key, modules, self.configuration.ignore_fields_with_bad_names)
      fields = zoho.module_fields
      File.open(File.join(base_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) } if cache_fields == true
    end
    zoho
  end

  require 'active_model'
  class Crm

    class << self
      attr_accessor :module_name
    end
    @module_name = 'Crm'

    def initialize(object_attribute_hash = {})
      @fields = object_attribute_hash == {} ? RubyZoho.configuration.api.fields(self.class.module_name) :
          object_attribute_hash.keys
      RubyZoho::Crm.create_accessor(self.class, @fields)
      RubyZoho::Crm.create_accessor(self.class, [:module_name])
      public_send(:module_name=, self.class.module_name)
      update_or_create_attrs(object_attribute_hash)
      self
    end

    def update_or_create_attrs(object_attribute_hash)
      retry_counter = object_attribute_hash.count
      begin
        object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
      rescue NoMethodError => e
        m = e.message.slice(/`(.*?)=/)
        RubyZoho::Crm.create_accessor(self.class, [m.gsub(/[`()]*/, '').chop]) unless m.nil?
        retry_counter -= 1
        retry if retry_counter > 0
      end
    end

    def attr_writers
      self.methods.grep(/\w=$/)
    end

    def self.create_accessor(klass, names)
      names.each do |name|
        n = name.class == Symbol ? name.to_s : name
        n.gsub!(/[()]*/, '')
        raise(RuntimeError, "Bad field name: #{name}") unless method_name?(n)
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

    def self.find(id)
      self.find_by_id(id)
    end

    def self.method_missing(meth, *args, &block)
      if meth.to_s =~ /^find_by_(.+)$/
        run_find_by_method($1, *args, &block)
      else
        super
      end
    end

    def method_missing(meth, *args, &block)
      if [:seid=, :semodule=].index(meth)
        run_create_accessor(self.class, meth)
        self.send(meth, args[0])
      else
        super
      end
    end

    def self.method_name?(n)
      name = n.class == String ? ApiUtils.string_to_symbol(n) : n
      return /[@$"]/ !~ name.inspect
    end

    def self.method_is_module?(str_or_sym)
      return nil if str_or_sym.nil?
      s = str_or_sym.class == String ? str_or_sym : ApiUtils.symbol_to_string(str_or_sym)
      possible_module = s[s.length - 1].downcase == 's' ? s : s + 's'
      i = RubyZoho.configuration.crm_modules.index(possible_module.capitalize)
      return str_or_sym unless i.nil?
      nil
    end

    def run_create_accessor(klass, meth)
      method = meth.to_s.chop.to_sym
      RubyZoho::Crm.create_accessor(klass, [method])
      nil
    end

    def self.run_find_by_method(attrs, *args, &block)
      attrs = attrs.split('_and_')
      conditions = Array.new(args.size, '=')
      h = RubyZoho.configuration.api.find_records(
          self.module_name, ApiUtils.string_to_symbol(attrs[0]), conditions[0], args[0]
      )
      return h.collect { |r| new(r) } unless h.nil?
      nil
    end

    def self.first
      r = RubyZoho.configuration.api.first(self.module_name)
      new(r[0])
    end

    def self.all         #TODO Refactor into low level API
      max_records = 200
      result = []
      i = 1
      batch = []
      until batch.nil?
        batch = RubyZoho.configuration.api.some(self.module_name, i, max_records)
        result.concat(batch) unless batch.nil?
        break if !batch.nil? && batch.count < max_records
        i += max_records
      end
      result.collect { |r| new(r) }
    end

    def << object
      object.semodule = self.module_name
      object.seid = self.id
      object.fields << :seid
      object.fields << :semodule
      save_object(object)
    end

    def attach_file(file_path, file_name)
      RubyZoho.configuration.api.attach_file(self.class.module_name, self.send(primary_key), file_path, file_name)
    end

    def create(object_attribute_hash)
      initialize(object_attribute_hash)
      save
    end

    def self.delete(id)
      RubyZoho.configuration.api.delete_record(self.module_name, id)
    end

    def primary_key
      RubyZoho.configuration.api.primary_key(self.class.module_name)
    end

    def save
      h = {}
      @fields.each { |f| h.merge!({ f => eval("self.#{f.to_s}") }) }
      h.delete_if { |k, v| v.nil? }
      r = RubyZoho.configuration.api.add_record(self.class.module_name, h)
      up_date(r)
    end

    def save_object(object)
      h = {}
      object.fields.each { |f| h.merge!({ f => object.send(f) }) }
      h.delete_if { |k, v| v.nil? }
      r = RubyZoho.configuration.api.add_record(object.module_name, h)
      up_date(r)
    end

    def self.update(object_attribute_hash)
      raise(RuntimeError, 'No ID found', object_attribute_hash.to_s) if object_attribute_hash[:id].nil?
      id = object_attribute_hash[:id]
      object_attribute_hash.delete(:id)
      r = RubyZoho.configuration.api.update_record(self.module_name, id, object_attribute_hash)
      new(object_attribute_hash.merge!(r))
    end

    def up_date(object_attribute_hash)
      update_or_create_attrs(object_attribute_hash)
      self
    end

    def self.setup_classes
      RubyZoho.configuration.crm_modules.each do |module_name|
        klass_name = module_name.chop
        c = Class.new(RubyZoho::Crm) do
          include RubyZoho
          include ActiveModel
          extend ActiveModel::Naming

          attr_reader :fields
          @module_name = module_name
        end
        const_set(klass_name, c)
      end
    end

    c = Class.new(RubyZoho::Crm) do
      def initialize(object_attribute_hash = {})
        Crm.module_name = 'Users'
        super
      end

      def self.delete(id)
        raise 'Cannot delete users through API'
      end

      def save
        raise 'Cannot delete users through API'
      end

      def self.all
        result = RubyZoho.configuration.api.users('AllUsers')
        result.collect { |r| new(r) }
      end

      def self.find_by_email(email)
        r = []
        self.all.index { |u| r << u if u.email == email }
        r
      end

      def self.method_missing(meth, *args, &block)
        Crm.module_name = 'Users'
        super
      end
    end

    Kernel.const_set 'User', c

  end
end
