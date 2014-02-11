require "spec_helper"

describe Model do
  describe ".field" do
    it "creates a getter and setter for the field" do
      define { field :name }

      client = Client.new
      client.name = "Rafer"

      expect(client.name).to eq("Rafer")
    end

    it "defaults :collection fields to an empty array" do
      define { field :name, :collection => true }

      client = Client.new
      expect(client.name).to eq([])
    end

    it "does not allow the :required attribute with :collection" do
      required_collection = lambda do
         define { field :name, :collection => true, :required => true }
       end

      expect(&required_collection).to raise_error(ArgumentError, /fields cannot be both :collection and :required/ )
    end
  end

  describe ".validate" do
    it "runs added validations each time #errors is called" do
      run_count = 0

      define do
        validate { run_count += 1 }
      end

      client = Client.new

      expect { client.errors }.to change { run_count }.to(1)
      expect { client.errors }.to change { run_count }.to(2)
    end

    describe "with no field name" do
      it "is passed the errors object" do
        define do
          validate { |e| e.add(:field, "ERROR") }
        end

        client = Client.new
        expect(client.errors[:field] ).to include("ERROR")
      end

      it "is executed after the built in field validations" do
        define do
          field :field, :required => true
          validate { |e| e.add(:field, "There were #{e[:field].size} errors") }
        end

        client = Client.new
        expect(client.errors[:field]).to include("There were 1 errors")
      end

      it "is not executed if there are any errors on the model with :always => false" do
        define do
          field :field, :required => true
          validate(:always => false) { |e| e.add(:field, "never happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil"])
      end

      it "is executed irrespetive of other errors with :always => true" do
        define do
          field :field, :required => true
          validate(:always => true) { |e| e.add(:field, "should happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil", "should happen"])
      end
      
      it "defaults :always to true" do
        define do
          field :field, :required => true
          validate { |e| e.add(:field, "should happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil", "should happen"])
      end
    end
    
    describe "with a field name" do
      it "is passed an errors object for that field" do
        define do
          field :field
          validate(:field) { |e| e.add("is not great")}
        end

        client = Client.new
        expect(client.errors[:field]).to include("is not great")
      end

      it "is not executed if there are already errors on the specified field with :always => false" do
        define do
          field :field, :required => true
          validate(:field, :always => false) { |e| e.add("never happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil"])
      end

      it "is executed irrespective of field errors with :always => true" do
        define do
          field :field, :required => true
          validate(:field, :always => true) { |e| e.add("should happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil", "should happen"])
      end

      it "defaults :always to false" do
        define do
          field :field, :required => true
          validate(:field) { |e| e.add("never happen") }
        end

        client = Client.new
        expect(client.errors[:field]).to eq(["cannot be nil"])
      end
    end
  end

  describe ".new" do
    before { define { field :name } }

    it "accepts fields" do
      client = Client.new(:name => "Rafer")
      expect(client.name).to eq("Rafer")
    end

    it "raises an exception for unrecognized parmeters" do
      expect { Client.new(:wrong => "") }.to raise_error(NoMethodError)
    end
  end

  describe ".errors" do
    it "is empty when no fields or validations have been defined" do
      define { }
      expect(Client.new.errors).to be_empty
    end

    it "includes errors for incorrect types" do
      define { field :field, :type => String }
      client = Client.new(:field => :wrong)

      expect(client.errors[:field]).to include("is not an instance of String (was Symbol)")
    end

    it "doesn't include errors for correct types" do
      define { field :field, :type => String }
      client = Client.new(:field => "right")

      expect(client.errors[:field]).to eq([])
    end

    it "doesn't include errors for correct subtypes" do
      define { field :field, :type => Numeric }
      client = Client.new(:field => 1)

      expect(client.errors[:field]).to eq([])
    end

    it "includes an error for required fields that are nil" do
      define { field :field, :required => true }
      client = Client.new(:field => nil)

      expect(client.errors[:field]).to include("cannot be nil")
    end

    it "doesn't include errors for non-required, typed fields" do
      define { field :field, :type => String }

      expect(Client.new.errors[:field]).to eq([])
    end

    it "includes errors for incorrect types (when multiple are specified)" do
      define { field :field, :type => [String, Symbol] }
      client = Client.new(:field => 1)

      expect(client.errors[:field]).to include("is not an instance of String or Symbol (was Fixnum)")
    end

    it "includes no errors for correct types (when multiple types are specified)" do
      define { field :field, :type => [String, Symbol] }

      expect(Client.new(:field => "right").errors[:field]).to eq([])
      expect(Client.new(:field => :right).errors[:field]).to eq([])
    end

    it "includes only the 'empty' error for fields that are required and typed, with a nil value" do
      define { field :field, :type => String, :required => true }
      client = Client.new(:field => nil)

      expect(client.errors[:field]).to include("cannot be nil")
    end

    it "includes errors for invalid collaborators (when :validate is specified)" do
      define { field :field, :validate => true }
      client = Client.new(:field => double(:valid? => false))

      expect(client.errors[:field]).to include("is invalid")
    end

    it "doesn't includes errors for valid collaborators (when :validate is specified)" do
      define { field :field, :validate => true }
      client = Client.new(:field => double(:valid? => true))

      expect(client.errors[:field]).to eq([])
    end

    it "doesn't validate collaborators if the type is incorrect" do
      define { field :field, :type => String, :validate => true }

      collaborator = double
      client       = Client.new(:field => collaborator)

      expect(collaborator).not_to receive(:valid?)

      client.errors
    end

    describe "collections" do
      it "includes an error if the value is not enumerable" do
        define { field :field, :type => String, :collection => true }
        client = Client.new(:field => 1)

        expect(client.errors[:field]).to include("was declared as a collection and is not enumerable")
      end

      it "doesn't include errors if there are no values" do
        define { field :field, :type => String, :collection => true }
        client = Client.new

        expect(client.errors[:field]).to eq([])
      end

      it "includes errors for incorrect types" do
        define { field :field, :type => String, :collection => true }
        client = Client.new(:field => [:wrong])

        expect(client.errors[:field]).to include("contains a value that is not an instance of String")
      end

      it "includes errors for incorrect types (multiple types)" do
        define { field :field, :type => [String, Symbol], :collection => true }
        client = Client.new(:field => [1])

        expect(client.errors[:field]).to include("contains a value that is not an instance of String or Symbol")
      end

      it "doesn't include errors for correctly typed values" do
        define { field :field, :type => String, :collection => true }
        client = Client.new(:field => ["right", "right"])

        expect(client.errors[:field]).to eq([])
      end

      it "doesn't include errors for correctly typed values (multiple types)" do
        define { field :field, :type => [String, Symbol], :collection => true }
        client = Client.new(:field => ["right", :right])

        expect(client.errors[:field]).to eq([])
      end

      it "includes errors for invalid collaborators (when :validate is specified)" do
        define { field :field, :validate => true, :collection => true }
        client = Client.new(:field => [double(:valid? => false)])

        expect(client.errors[:field]).to include("is invalid")
      end

      it "doesn't include errors for valid collaborators (when :validate is specified)" do
        define { field :field, :validate => true, :collection => true }
        client = Client.new(:field => [double(:valid? => true)])

        expect(client.errors[:field]).to eq([])
      end

      it "doesn't validate collaborators if the type is incorrect" do
        define { field :field, :type => String, :validate => true, :collection => true }

        collaborator = double
        client       = Client.new(:field => [collaborator])

        expect(collaborator).not_to receive(:valid?)

        client.errors
      end
    end
  end

  describe "#==" do
    before { define { field :field } }

    it "is true if all fields are equal" do
      client_1 = Client.new(:field => "A")
      client_2 = Client.new(:field => "A")

      expect(client_1).to eq(client_2)
    end

    it "is false if any field is different" do
      client_1 = Client.new(:field => "A")
      client_2 = Client.new(:field => "B")

      expect(client_1).not_to eq(client_2)
    end

    it "is false if the object is of another type" do
      expect(Client.new).not_to eq(double)
    end
  end

  describe "#inspect" do
    before { define { field :field } }

    it "shows the name and value of all fields" do
      client = Client.new(:field => "VALUE")
      expect(client.inspect).to match(/field: "VALUE"/)
    end
  end

  describe "#valid?" do
    it "is true if there are no errors" do
      define { field :field }
      expect(Client.new.valid?).to be(true)
    end

    it "is false if there are errors" do
      define { field :field, :required => true }
      expect(Client.new.valid?).to be(false)
    end
  end

  describe "#attributes" do
    it "returns the models as a hash" do
      define { field :field }
      client = Client.new(:field => "VALUE")

      expect(client.attributes).to eq({:field => "VALUE"})
    end
  end

  def define(&block)
    client = Class.new do
      include Model
      instance_eval(&block)
    end
    stub_const("Client", client)
  end
end
