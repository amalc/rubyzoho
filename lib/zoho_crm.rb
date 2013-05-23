require 'active_model'
require 'zoho_crm_crud_methods'
require 'zoho_crm_utils'

class ZohoCrm

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

  def self.run_find_by_method(attrs, *args, &block)
    attrs = attrs.split('_and_')
    conditions = Array.new(args.size, '=')
    h = RubyZoho.configuration.api.find_records(
        self.module_name, ApiUtils.string_to_symbol(attrs[0]), conditions[0], args[0]
    )
    return h.collect { |r| new(r) } unless h.nil?
    nil
  end

  def << object
    object.semodule = self.module_name
    object.seid = self.id
    object.fields << :seid
    object.fields << :semodule
    save_object(object)
  end

  def primary_key
    RubyZoho.configuration.api.primary_key(self.class.module_name)
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

  require 'zoho_crm_users'

end
