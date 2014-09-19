# DomainModel

Domain provides a minimal set of utilties for declaring object attributes with optional type and validation support.

## Usage

The foundation of DomainModel is the ability to declare a field.

```ruby
class Person
  include DomainModel

  field :name
end
```

Declaring a field defines getters and setters, like attr_accessor:

```ruby
  person = Person.new # => "#<Person name: nil>"
  person.name = "Horrace" # => "Horrace"
  person.name # => "Horrace"
```

It also provides a hash-based constructor:

```ruby
  person = Person.new(:name => "Scrumbs")
  person.name # => "Scrumbs"
```

### Validation

DomainModel provides a simple validation infrastructure.

```ruby
  class Person
    include DomainModel

    field :name, :required => true
  end
```

Now a `Person` can be asked about its validity:

```ruby
  person = Person.new
  person.valid? #=> false
  person.errors #=> #<DomainMode::ModelErrors {:name=>["cannot be nil"]}>
```

Unlike `ActiveModel`, it's not necesary to call `#valid?` to set `#errors`.

`#errors` returns an instance of `DomainModel::ModelErrors`.

```ruby
  errors = person.errors

  # All fields that have at least 1 error
  errors.fields # => [:name]

  # The errors for a particular field
  errors[:name] # =>  ["cannot be nil"]

  # ModelErrors#[] will always return an array, even for fields that don't have errors or don't exist.
  errors[:unknown] # => []

  # ModelErrors knows if it's empty
  errors.empty? # => false

  # And it's enumerable like a hash
  errors.map { |k, v| "#{k}: #{v.inspect}" } # => ["name: [\"cannot be nil\"]"]
```

DomainModel also allows you to declare a type for a field.

```ruby
  require "time"

  class Person
    include DomainModel

    field :born_at, :type => Time
  end

  Person.new(:born_at => "A WHILE AGO").errors # => #<DomainMode::ModelErrors {:born_at=>["is not an instance of Time (was String)"]}>
  Person.new(:born_at => Time.parse("June 8, 1987")).errors # => #<DomainMode::ModelErrors {}> 
```

Or multiple types for a field:

```ruby
  require "time"

  class Person
    include DomainModel

    field :born_at, :type => [Date, Time]
  end

  Person.new(:born_at => "A WHILE AGO").errors # => #<DomainMode::ModelErrors {:born_at=>["is not an instance of Time (was String)"]}>
  Person.new(:born_at => Time.parse("June 8, 1987")).errors # => #<DomainMode::ModelErrors {}> 
  Person.new(:born_at => Date.parse("June 8, 1987")).errors # => #<DomainMode::ModelErrors {}> 
```

Now `Person#born_at` will be valid if it  is a `Date` or a `Time`.


DomainModel does not make any attempt to cast based on type, nor does it disallow the setting of other types; it merely requires that the value be of the correct type to be considered valid.


## Development

To run the tests (assuming you have already run `gem install bundler`):

    bundle install && bundle exec rake
