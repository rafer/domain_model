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
    errors = Errors.new

    self.class.fields.each do |field|
      errors.add(field.name, field.errors(self.send(field.name)))
    end

    self.class.validations.each { |v| instance_exec(errors, &v) }

    errors
  end

  def ==(other)
    self.class.fields.map(&:name).all? do |name|
      self.send(name) == other.send(name)
    end
  end

  def inspect
    "#<#{self.class.name} " + self.class.fields.map { |f| "#{f.name}: #{send(f.name).inspect}" }.join(", ") + ">"
  end

  module ClassMethods
    def validate(&block)
      @validations ||= []
      validations << block
    end

    def field(*args)
      fields << (field = Field.new(*args))
      attr_accessor(field.name)
    end

    def fields
      @fields ||= []
    end

    def validations
      @validations ||= []
    end
  end

  class Field
    attr_reader :name, :types

    def initialize(name, options = {})
      @name       = name
      @required   = options.fetch(:required, false)
      @collection = options.fetch(:collection, false)

      raw_type = options.fetch(:type, BasicObject)
      @types   = raw_type.is_a?(Module) ? [raw_type] : raw_type

      if required? and collection?
        raise ArgumentError, "fields cannot be both :collection and :required"
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

  class Errors
    def initialize
      @hash = Hash.new
    end

    def add(field_name, error)
      @hash[field_name] ||= []
      @hash[field_name] += Array(error)
    end

    def [](field_name)
      @hash[field_name] || []

    end

    def empty?
      @hash.values.flatten.empty?
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
        when (type_mismatch? and not legitimately_empty?)
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

      def legitimately_empty?
        value.nil? and not field.required?
      end
    end
  end
end

require "model/version"
