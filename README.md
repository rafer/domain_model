# DomainModel

DomainModel provides a minimal set of utilties for declaring object attributes with optional type and validation support.

## Usage

Add DomainModel to your class like this:

	class Fish
	  include DomainModel
	end

Then add attributes to your class using the keyword `field` like this:

	class Fish
	  include DomainModel

	  field :color, :required => true, :type => String
	  field :size, :type => Float, :validate => true
	  field :habitat, :type => Habitat, :validate => true
	  ...

	end

	class Habitat
	  include DomainModel

	  field :temperature, :type => Float, :validate => true
	  field :bottom_type, :type => String

	  ...
	end


The name of your field (or attribute) is required. When you specify a field, you get getters and setters automatically:

	red_fish = Fish.new
	red_fish.color = "red"
	red_fish.habitat = Habitat.new({
	  :temperature => 75.0,
	  :bottom_type => "sand"
	)

A field has these optional attributes:

Attribute     | Description
------------- | -----------
`:type`       | The type of the field, which could be any valid Ruby Object type, including custom classes.
`:required`   | Is this a required field? Used for validation.
`:collection` | The field is an array of values. Note that you can't have a required collection.
`:validate`   | Validate the field. If this is a collection, will validate the collection's items too.

You can extend the validation with custom code in your class:

	validate :size do |errors|
	  if size < 0.0 || size > 500.0 # In our world fish can only be so big
	    errors.add("has to be between 0.0 and 500.0")
	  end
	end

Then when you create an instance of your class, you can ask if the class is valid and get any errors:

	my_fish = Fish.new({ :color => "green", :size => "-10" })
	if my_fish.valid?
	  go_fishing
	else
	  my_fish.errors
	end

`errors` is a Enumerable object of error objects. If you want to print out all of the error messages from validation, you'll want to get the `flat_errors` which is an array of the error messages. If you have nested DomainModel objects and you want to see all the errors, use `flat_errors`.


## Development

To run the tests (assuming you have already run `gem install bundler`):

    bundle install && bundle exec rake
