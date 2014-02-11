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
    errors = ModelErrors.new

    self.class.fields.each do |field|
      errors.add(field.name, field.errors(self.send(field.name)))
    end

    self.class.validations.each { |v| v.execute(self, errors) }

    errors
  end

  def valid?
    errors.empty?
  end

  def ==(other)
    other.is_a?(self.class) && attributes == other.attributes
  end

  def inspect
    "#<#{self.class} " + attributes.map { |n, v| "#{n}: #{v.inspect}" }.join(", ") + ">"
  end

  def attributes
    attributes = {}
    self.class.fields.map(&:name).each do |name|
      attributes[name] = send(name)
    end
    attributes
  end

  module ClassMethods
    def validate(*args, &block)
      @validations ||= []
      validations << Validation.new(*args, &block)
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
      @validate   = options.fetch(:validate, false)

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

    def validate?
      !!@validate
    end
  end

  class ModelErrors
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

  class FieldErrors
    def initialize(model_errors, field)
      @model_errors, @field = model_errors, field
    end

    def add(error)
      @model_errors.add(@field.name, error)
    end

    def empty?
      @model_errors[@field.name].empty?
    end
  end

  class Validation
    def initialize(*args, &block)
      @field_name = args[0] if args[0].is_a?(Symbol)
      @options    = args[0] if args[0].is_a?(Hash)
      @options    = args[1] if args[1].is_a?(Hash)
      @options    = {} if @options.nil?

      @block      = block
    end

    def execute(model, errors)
      if global?
        if not clean? or errors.empty?
          model.instance_exec(errors, &@block)
        end
      else
        field = model.class.fields.find { |f| f.name == @field_name}
        raise("No field called #{@field_name}") if field.nil?

        field_errors = FieldErrors.new(errors, field)

        if not clean? or field_errors.empty?
          model.instance_exec(field_errors, &@block)
        end
      end
    end

    def global?
      @field_name.nil?
    end

    def clean?
      @options.fetch(:clean, false)
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
        when transitively_invalid?
          ["is invalid"]
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
        values.any? do |value|
          field.types.none? { |t| value.is_a?(t) }
        end
      end

      def transitively_invalid?
        field.validate? and values.any? { |v| not v.valid? }
      end
    end

    class Scalar < Validator
      def initialize(field, value)
        @field, @value = field, value
      end

      def errors
        case
        when legitimately_empty?
          []
        when (value.nil? and field.required?)
          ["cannot be nil"]
        when type_mismatch?
          ["is not an instance of #{type_string} (was #{value.class.inspect})"]
        when transitively_invalid?
          ["is invalid"]
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

      def transitively_invalid?
        field.validate? and not value.valid?
      end
    end
  end
end

require "model/version"
