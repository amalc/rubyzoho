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

Kernel.const_set 'CRMUser', c
