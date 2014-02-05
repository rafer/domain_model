require "spec_helper"

module Model  
  describe Model do
    class TheModel
      include Model
    end

    describe ".field" do
      it "creates a getter and setter for the field" do
        instance = Class.new(TheModel) { field :name }.new
        instance.name = "Rafer"

        expect(instance.name).to eq("Rafer")
      end
      
      it "defaults :collection fields to an empty array" do
        instance = Class.new(TheModel) { field :name, :collection => true }.new
        expect(instance.name).to eq([])
      end
      
      it "does not allow the :required attribute with :collection" do
        required_collection = lambda { Class.new(TheModel) { field :name, :collection => true, :required => true } }
        expect(&required_collection).to raise_error(ArgumentError, /fields cannot be both required a collection and required/ )
      end
    end

    describe ".new" do
      let(:klass) { Class.new(TheModel) { field :name } }

      it "accepts fields" do
        client = klass.new(:name => "Rafer")
        expect(client.name).to eq("Rafer")
      end

      it "raises an exception for unrecognized parmeters" do
        expect { klass.new(:wrong => "") }.to raise_error(NoMethodError)
      end
    end

    describe ".errors" do
      it "includes errors for incorrect types" do
        klass    = Class.new(TheModel) { field :field, :type => String }
        instance = klass.new(:field => :wrong)
        
        expect(instance.errors[:field]).to include("is not an instance of String (was Symbol)")
      end

      it "include no errors for correct types" do
        klass    = Class.new(TheModel) { field :field, :type => String }
        instance = klass.new(:field => "right")

        expect(instance.errors[:field]).to be_empty
      end

      it "include no errors for correct subtypes" do
        klass    = Class.new(TheModel) { field :field, :type => Object }
        instance = klass.new(:field => "right")

        expect(instance.errors[:field]).to be_empty
      end

      it "includes errors for incorrect types (when multiple are specified)" do
        klass    = Class.new(TheModel) { field :field, :type => [String, Symbol] }
        instance = klass.new(:field => 1)
        
        expect(instance.errors[:field]).to include("is not an instance of String or Symbol (was Fixnum)")
      end
      
      it "includes no errors for correct types (when multiple types are specified)" do
        klass = Class.new(TheModel) { field :field, :type => [String, Symbol] }

        expect(klass.new(:field => "right").errors[:field]).to be_empty
        expect(klass.new(:field => :right).errors[:field]).to be_empty
      end

      it "includes an error for required fields that are nil" do
        klass    = Class.new(TheModel) { field :field, :required => true }
        instance = klass.new(:field => nil)

        expect(instance.errors[:field]).to include("cannot be empty")
      end
      
      it "includes only the 'empty' error for fields that are required and typed, with a nil value" do
        klass    = Class.new(TheModel) { field :field, :type => String, :required => true }
        instance = klass.new(:field => nil)

        expect(instance.errors[:field]).to include("cannot be empty")
      end
      
      it "includes errors for incorrect types for collections" do
        klass    = Class.new(TheModel) { field :field, :type => String, :collection => true }
        instance = klass.new(:field => [:wrong])

        expect(instance.errors[:field]).to include("contains a value that is not an instance of String")
      end

      it "includes errors for incorrect types for collections (when multiple are types are specified)" do
        klass    = Class.new(TheModel) { field :field, :type => [String, Symbol], :collection => true }
        instance = klass.new(:field => [1])

        expect(instance.errors[:field]).to include("contains a value that is not an instance of String or Symbol")
      end
      
      it "includes no errors errors when a collection has all the right types" do
        klass    = Class.new(TheModel) { field :field, :type => String, :collection => true }
        instance = klass.new(:field => ["right", "right"])

        expect(instance.errors[:field]).to be_empty
      end
      
      it "includes an error when a collection is not enumerable" do
        klass    = Class.new(TheModel) { field :field, :type => String, :collection => true }
        instance = klass.new(:field => 1)
        
        expect(instance.errors[:field]).to include("was declared as a collection and is not enumerable")
      end

      it "includes no errors for correct types (when multiple are specified, in a collection)" do
        klass = Class.new(TheModel) { field :field, :type => [String, Symbol], :collection => true }
      
        expect(klass.new(:field => ["right", :right]).errors[:field]).to be_empty
      end
    end
  end
end
