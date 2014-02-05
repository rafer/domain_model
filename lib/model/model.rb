require "model"

module Model
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
      def self.errors(*args)
        new(*args).errors
      end

      def initialize(field, value)
        @field, @value = field, value
      end

      def errors
        case
        when (collection? and not enumerable?)
          ["was declared as a collection and is not enumerable"]
        when (value.nil? and required?)
          ["cannot be empty"]
        when (type_mismatch? and collection?)
          ["contains a value that is not an instance of #{types.map(&:inspect).join(' or ')}"]
        when (type_mismatch? and not collection?)
          ["is not an instance of #{types.map(&:inspect).join(' or ')} (was #{value.class.inspect})"]
        else
          []
        end
      end
      
      private 
      
      attr_reader :field, :value
      
      def types
        field.types
      end
      
      def required?
        field.required?
      end

      def collection?
        field.collection?
      end
            
      def type_mismatch?
        Array(value).any? do |v|
          types.none? { |t| v.is_a?(t) } 
        end
      end
      
      def enumerable?
        @value.is_a?(Enumerable)
      end
    end
  end
end
