require 'zoho_api'
require 'api_utils'
require 'yaml'


module RubyZoho

  class Configuration
    attr_accessor :api, :api_key, :cache_fields, :crm_modules

    def initialize
      self.api_key = nil
      self.api = nil
      self.cache_fields = false
      self.crm_modules = nil
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
      zoho = ZohoApi::Crm.new(api_key, modules, fields)
    else
      zoho = ZohoApi::Crm.new(api_key, modules)
      fields = zoho.module_fields
      File.open(File.join(base_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) } if cache_fields == true
    end
    zoho
  end

  class Crm

    class << self
      attr_accessor :module_name
    end

    def initialize(object_attribute_hash = {})
      @fields = object_attribute_hash == {} ? RubyZoho.configuration.api.fields(RubyZoho::Crm.module_name) :
          object_attribute_hash.keys
      RubyZoho::Crm.create_accessor(self.class, @fields)
      RubyZoho::Crm.create_accessor(self.class, [:module_name])
      public_send(:module_name=, RubyZoho::Crm.module_name)
      retry_counter = object_attribute_hash.count
      begin
        object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
      rescue NoMethodError => e
        m = e.message.slice(/`(.*?)=/)
        unless m.nil?
          m.gsub!('`', '')
          m.gsub!('(', '')
          m.gsub!(')', '')
          RubyZoho::Crm.create_accessor(self.class, [m.chop])
        end
        retry_counter -= 1
        retry if retry_counter > 0
      end
      self
    end

    def attr_writers
      self.methods.grep(/\w=$/)
    end

    def self.create_accessor(klass, names)
      names.each do |name|
        n = name
        n = name.to_s if name.class == Symbol
        raise(RuntimeError, "Bad field name: #{name}") unless method_name?(name)
        create_getter(klass, n)
        create_setter(klass, n)
      end
      names
    end

    def self.method_name?(n)
      name = n.class == String ? ApiUtils.string_to_symbol(n) : n
      return /[@$"]/ !~ name.inspect
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
          Crm.module_name, ApiUtils.string_to_symbol(attrs[0]), conditions[0], args[0]
      )
      return h.collect { |r| new(r) } unless h.nil?
      nil
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

    def << object
      object.semodule = self.module_name
      object.seid = self.id
      object.fields << :seid
      object.fields << :semodule
      save_object(object)
    end

    def attach_file(file_path, file_name)
      RubyZoho.configuration.api.attach_file(Crm.module_name, self.send(primary_key), file_path)
    end

    def create(object_attribute_hash)
      initialize(object_attribute_hash)
      save
    end

    def self.delete(id)
      RubyZoho.configuration.api.delete_record(Crm.module_name, id)
    end

    def primary_key
      RubyZoho.configuration.api.primary_key(Crm::module_name)
    end

    def save
      h = {}
      @fields.each { |f| h.merge!({ f => eval("self.#{f.to_s}") }) }
      h.delete_if { |k, v| v.nil? }
      r = RubyZoho.configuration.api.add_record(Crm.module_name, h)
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
      r = RubyZoho.configuration.api.update_record(Crm.module_name, id, object_attribute_hash)
      new(object_attribute_hash.merge!(r))
    end

    def up_date(object_attribute_hash)
      retry_counter = object_attribute_hash.length
      begin
        object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
      rescue NoMethodError => e
        m = e.message.slice(/`(.*?)=/)
        unless m.nil?
          m.gsub!('`', '')
          m.gsub!('(', '')
          m.gsub!(')', '')
          RubyZoho::Crm.create_accessor(self.class, [m.chop])
        end
        retry_counter -= 1
        retry if retry_counter > 0
      end
      self
    end


    def self.setup_classes
      RubyZoho.configuration.crm_modules.each do |module_name|
        klass_name = module_name.chop
        c = Class.new(RubyZoho::Crm) do
          include RubyZoho
          attr_reader :fields

          def initialize(object_attribute_hash = {})
            klass = self.class.to_s
            Crm.module_name = klass.slice(klass.rindex('::') + 2, klass.length) + 's'
            super
          end

          def self.all
            klass = self.to_s
            Crm.module_name = klass.slice(klass.rindex('::') + 2, klass.length) + 's'
            super
          end

          def self.delete(id)
            klass = self.to_s
            Crm.module_name = klass.slice(klass.rindex('::') + 2, klass.length) + 's'
            super
          end

          def self.find(id)
            klass = self.to_s
            Crm.module_name = klass.slice(klass.rindex('::') + 2, klass.length) + 's'
            super
          end

          def self.method_missing(meth, *args, &block)
            klass = self.to_s
            Crm.module_name = klass.slice(klass.rindex('::') + 2, klass.length) + 's'
            super
          end
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
