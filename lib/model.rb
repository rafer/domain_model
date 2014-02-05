module Model
  def self.included(base)
    base.extend(ClassMethods)
  end

  def initialize(params={})
    self.class.fields.select(&:collection?).each do |field|
      params[field.name] ||= []
    end
    
    params.each { |k,v | send("#{k}=", v) }
  end

  def errors
    errors = Hash.new { [] }

    self.class.fields.each do |field|
      errors[field.name] = field.errors(self.send(field.name))
    end

    errors
  end

  module ClassMethods
    def field(*args)
      @fields ||= []
      field = Field.new(*args)
      attr_accessor(field.name)
      fields << field
    end
    
    def fields
      @fields
    end
  end

  class Field
    attr_reader :name, :types

    def initialize(name, options = {})
      @name       = name
      @types      = Array(options.fetch(:type, BasicObject))
      @required   = options.fetch(:required, false)
      @collection = options.fetch(:collection, false)
      
      if required? and collection?
        raise ArgumentError, "fields cannot be both required a collection and required" 
      end
    end

    def errors(value)
      Validator.errors(self, value)
    end

    def required?
      !!@required
    end

    def collection?
      !!@collection
    end      
  end

  class Validator
    def self.errors(field, value)
      validator = field.collection? ? Collection : Scalar
      validator.new(field, value).errors
    end

    private
    
    attr_reader :field
    
    def types
      field.types
    end
    
    class Collection < Validator
      def initialize(field, values)
        @field, @values = field, values
      end

      def errors
        case
        when (not enumerable?)
          ["was declared as a collection and is not enumerable"]
        when type_mismatch?
          ["contains a value that is not an instance of #{types.map(&:inspect).join(' or ')}"]
        else
          []
        end
      end

      private

      attr_reader :values

      def enumerable?
        values.is_a?(Enumerable)
      end
    
      def type_mismatch?
        values.all? do |value|
          field.types.none? { |t| value.is_a?(t) }
        end
      end
    end
  
    class Scalar < Validator
      def initialize(field, value)
        @field, @value = field, value
      end

      def errors
        case
        when (value.nil? and field.required?)
          ["cannot be empty"]
        when type_mismatch?
          ["is not an instance of #{type_string} (was #{value.class.inspect})"]
        else
          []
        end
      end
    
      private 
    
      attr_reader :value
                
      def type_mismatch?
        types.none? { |t| value.is_a?(t) } 
      end
      
      def type_string
        types.map(&:inspect).join(' or ')
      end
    end
  end
end

require "model/version"
