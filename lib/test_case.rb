require 'pp'

module TestCase

  class Outer

    class << self
      attr_accessor :module_name
    end

    @module_name = 'Crm'

    def module_name
      self.class.module_name
    end

    def self.setup_classes
      modules = %w[Accounts Leads]
      modules.each do |module_name|
        klass_name = module_name.chop
        c = Class.new(TestCase::Outer) do
          include TestCase
          @module_name = module_name
        end
        const_set(klass_name, c)
      end
    end

    setup_classes

  end

end