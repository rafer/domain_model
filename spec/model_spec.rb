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
       
      expect(&required_collection).to raise_error(ArgumentError, /fields cannot be both required a collection and required/ )
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
    it "is no fields or validations have been defined" do
      define { }
      expect(Client.new.errors).to be_empty
    end
    
    it "includes errors for incorrect types" do
      define { field :field, :type => String }
      client = Client.new(:field => :wrong)
      
      expect(client.errors[:field]).to include("is not an instance of String (was Symbol)")
    end

    it "include no errors for correct types" do
      define { field :field, :type => String }
      client = Client.new(:field => "right")

      expect(client.errors[:field]).to be_empty
    end

    it "include no errors for correct subtypes" do
      define { field :field, :type => Object }
      client = Client.new(:field => "right")

      expect(client.errors[:field]).to be_empty
    end

    it "includes errors for incorrect types (when multiple are specified)" do
      define { field :field, :type => [String, Symbol] }
      client = Client.new(:field => 1)
      
      expect(client.errors[:field]).to include("is not an instance of String or Symbol (was Fixnum)")
    end
    
    it "includes no errors for correct types (when multiple types are specified)" do
      define { field :field, :type => [String, Symbol] }

      expect(Client.new(:field => "right").errors[:field]).to be_empty
      expect(Client.new(:field => :right).errors[:field]).to be_empty
    end

    it "includes an error for required fields that are nil" do
      define { field :field, :required => true }
      client = Client.new(:field => nil)

      expect(client.errors[:field]).to include("cannot be empty")
    end
    
    it "includes only the 'empty' error for fields that are required and typed, with a nil value" do
      define { field :field, :type => String, :required => true }
      client = Client.new(:field => nil)

      expect(client.errors[:field]).to include("cannot be empty")
    end
    
    it "includes errors for incorrect types in collections" do
      define { field :field, :type => String, :collection => true }
      client = Client.new(:field => [:wrong])

      expect(client.errors[:field]).to include("contains a value that is not an instance of String")
    end

    it "includes errors for incorrect types in collections (when multiple are types are specified)" do
      define { field :field, :type => [String, Symbol], :collection => true }
      client = Client.new(:field => [1])

      expect(client.errors[:field]).to include("contains a value that is not an instance of String or Symbol")
    end
    
    it "includes no errors errors when a collection has all the right types" do
      define { field :field, :type => String, :collection => true }
      client = Client.new(:field => ["right", "right"])

      expect(client.errors[:field]).to be_empty
    end
    
    it "includes an error when a collection is not enumerable" do
      define { field :field, :type => String, :collection => true }
      client = Client.new(:field => 1)
      
      expect(client.errors[:field]).to include("was declared as a collection and is not enumerable")
    end

    it "includes no errors for correct types (when multiple are specified, in a collection)" do
      define { field :field, :type => [String, Symbol], :collection => true }
      client = Client.new(:field => ["right", :right])
    
      expect(client.errors[:field]).to be_empty
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
