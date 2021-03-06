module DomainModel
  InvalidModel = Class.new(StandardError)

  def self.included(base)
    base.extend(ClassMethods)
  end

  def initialize(attributes={})
    self.class.fields.select(&:collection?).each do |field|
      send("#{field.name}=", [])
    end

    attributes.each { |k,v | send("#{k}=", v) }
  end

  def errors
    errors = ModelErrors.new

    self.class.fields.each do |field|
      errors.add(field.name, field.errors(self.send(field.name)))
    end

    self.class.validations.each { |v| v.execute(self, errors) }

    errors
  end

  def flat_errors
    errors = self.errors

    self.class.fields.each do |field|
      next unless field.validate?

      value = self.send(field.name)

      if !field.collection? && value.is_a?(DomainModel)
        value.flat_errors.each { |k, v| errors.add(:"#{field.name}.#{k}", v) }
      end

      if field.collection? && value.is_a?(Enumerable)
        value.each_with_index do |element, index|
          if element.is_a?(DomainModel)
            element.flat_errors.each { |k, v| errors.add(:"#{field.name}[#{index}].#{k}", v) }
          end
        end
      end
    end

    errors
  end

  def valid?
    errors.empty?
  end

  def valid!
    cached_errors = errors # Just in case #errors is non-deterministic

    if !cached_errors.empty?
      raise InvalidModel.new("This #{self.class} object contains the following errors: #{cached_errors.to_hash}")
    end
  end

  def ==(other)
    other.is_a?(self.class) && attributes == other.attributes
  end

  def to_s
    inspect
  end

  def inspect
    "#<#{self.class} " + attributes.map { |n, v| "#{n}: #{v.inspect}" }.join(", ") + ">"
  end

  def empty?
    self.class.fields.all? { |f| send(f.name).nil? }
  end

  def attributes
    attributes = {}
    self.class.fields.map(&:name).each do |name|
      attributes[name] = send(name)
    end
    attributes
  end

  def to_primitive
    Serializer.serialize(self)
  end

  module ClassMethods
    def validate(*args, &block)
      validations << Validation.new(*args, &block)
    end

    def field(*args)
      fields << (field = Field.new(*args))
      attr_accessor(field.name)
    end

    def fields
      @fields ||= begin
        superclass.include?(DomainModel) ? (superclass.fields.dup) : []
      end
    end

    def validations
      @validations ||= begin
        superclass.include?(DomainModel) ? (superclass.validations.dup) : []
      end
    end

    def from_primitive(primitive)
      Deserializer.deserialize(self, primitive)
    end
  end

  class Serializer
    def self.serialize(object)
      new.serialize(object)
    end

    def serialize(object)
      case object
      when DomainModel
        serialize(object.attributes)
      when Hash
        object.each {|k,v| object[k] = serialize(v) }
      when Array
        object.map { |o| serialize(o) }
      else
        object
      end
    end
  end

  class Deserializer
    def self.deserialize(type, primitive)
      new.deserialize(type, primitive)
    end

    def deserialize(type, primitive)
      case
      when type <= DomainModel
        primitive ||= {}
        primitive.each do |k, v|
          field = type.fields.find { |f| f.name.to_s == k.to_s }

          next unless field && field.monotype

          if field.collection?
            primitive[k] = (v || []).map { |e| deserialize(field.monotype, e) }
          else
            primitive[k] = deserialize(field.monotype, v)
          end
        end

        type.new(primitive)
      else
        primitive
      end
    end
  end

  class Field
    attr_reader :name, :types

    def initialize(name, options = {})
      @name       = name
      @required   = options.fetch(:required, false)
      @collection = options.fetch(:collection, false)
      @validate   = options.fetch(:validate, false)

      raw_type = options.fetch(:type, Object)
      @types   = raw_type.is_a?(Module) ? [raw_type] : raw_type

      if required? and collection?
        raise ArgumentError, "fields cannot be both :collection and :required"
      end
    end

    def errors(value)
      Validator.errors(self, value)
    end

    def monotype
      types.first if types.count == 1
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
    include Enumerable

    def initialize
      @hash = Hash.new
    end

    def add(field_name, error)
      errors = Array(error)

      return if errors.empty?

      @hash[field_name] ||= []
      @hash[field_name] += Array(error)
    end

    def [](field_name)
      @hash[field_name] || []
    end

    def empty?
      @hash.values.flatten.empty?
    end

    def each(&block)
      @hash.each(&block)
    end

    def fields
      @hash.keys
    end

    def as_json(*)
      @hash.clone
    end

    def to_hash
      @hash.clone
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
        if always? or errors.empty?
          model.instance_exec(errors, &@block)
        end
      else
        field = model.class.fields.find { |f| f.name == @field_name}
        raise("No field called #{@field_name}") if field.nil?

        field_errors = FieldErrors.new(errors, field)

        if always? or field_errors.empty?
          model.instance_exec(field_errors, &@block)
        end
      end
    end

    def global?
      @field_name.nil?
    end

    def always?
      @options.fetch(:always, global?)
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

require "domain_model/version"
