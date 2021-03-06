require "spec_helper"

describe "Rails::Mongoid" do

  before(:all) do
    require "rails/mongoid"
  end

  describe ".create_indexes" do

    context "when an exception is raised" do

      let(:model) do
        stub
      end

      before do
        Rails::Mongoid.expects(:determine_model).returns(model)
        model.expects(:create_indexes).raises(Mongo::MongoArgumentError)
      end

      it "is not swallowed" do
        expect {
          Rails::Mongoid.create_indexes("spec/app/models/**/*.rb")
        }.to raise_error(Mongo::MongoArgumentError)
      end
    end

    context "when models exist in subdirectories" do

      context "when the model is namespaced" do

        module Twitter
          class Follow
            include Mongoid::Document
          end
        end

        let(:files) do
          ["/app/models/twitter/follow.rb"]
        end

        before do
          Dir.expects(:glob).with("/app/models/**/*.rb").returns(files)
        end

        it "loads the model with the namespacing" do
          Twitter::Follow.expects(:create_indexes).once
          Rails::Mongoid.create_indexes("/app/models/**/*.rb")
        end
      end

      context "when the model is not namespaced" do

        class Unfollow
          include Mongoid::Document
        end

        let(:files) do
          ["/app/models/twitter/unfollow.rb"]
        end

        before do
          Dir.expects(:glob).with("/app/models/**/*.rb").returns(files)
        end

        it "loads the model with the namespacing" do
          Unfollow.expects(:create_indexes).once
          Rails::Mongoid.create_indexes("/app/models/**/*.rb")
        end
      end
    end

    context "with ordinary Rails models" do

      let(:model_paths) do
        Dir.glob("spec/app/models/**/*.rb")
      end

      let(:models) do
        [].tap do |documents|
          model_paths.each do |file|
            file_path = Pathname.new(file).realpath
            spec_path = Pathname.new("spec/app/models").realpath
            model_path = file_path.relative_path_from(spec_path).to_s.gsub('.rb', '').split('/')
            begin
              klass = model_path.map { |path| path.camelize }.join('::').constantize
              if klass.ancestors.include?(Mongoid::Document) && !klass.embedded
                documents << klass
              end
            rescue
            end
          end
        end
      end

      before do
        models.each do |klass|
          klass.expects(:create_indexes).once
        end
      end

      it "creates the indexes for each model" do
        Rails::Mongoid.create_indexes("spec/app/models/**/*.rb")
      end
    end

    context "with models present in Rails engines" do

      let(:files) do
        ["/gem_path/engines/some_engine_gem/app/models/carrot.rb"]
      end

      before do
        class Carrot
          include Mongoid::Document
        end

        Dir.expects(:glob).with("/gem_path/engines/some_engine_gem/app/models/**/*.rb").returns(files)
      end

      it "requires the models by base name from the engine's app/models dir" do
        Carrot.expects(:create_indexes).once
        Rails::Mongoid.create_indexes("/gem_path/engines/some_engine_gem/app/models/**/*.rb")
      end
    end
  end

  describe ".preload_models" do

    let(:app) do
      stub(:config => config)
    end

    let(:config) do
      stub(:paths => paths)
    end

    let(:paths) do
      { "app/models" => [ "/rails/root/app/models" ] }
    end

    context "when preload models config is false" do

      let(:files) do
        [
          "/rails/root/app/models/user.rb",
          "/rails/root/app/models/address.rb"
        ]
      end

      before(:all) do
        Mongoid.preload_models = false
        Dir.stubs(:glob).with("/rails/root/app/models/**/*.rb").returns(files)
      end

      it "does not load any models" do
        Rails::Mongoid.expects(:load_model).never
        Rails::Mongoid.preload_models(app)
      end
    end

    context "when preload models config is true" do

      before(:all) do
        Mongoid.preload_models = true
      end

      context "when all models are in the models directory" do

        let(:files) do
          [
            "/rails/root/app/models/user.rb",
            "/rails/root/app/models/address.rb"
          ]
        end

        before do
          Dir.expects(:glob).with("/rails/root/app/models/**/*.rb").returns(files)
        end

        it "requires the models by basename" do
          Rails::Mongoid.expects(:load_model).with("address")
          Rails::Mongoid.expects(:load_model).with("user")
          Rails::Mongoid.preload_models(app)
        end
      end

      context "when models exist in subdirectories" do

        let(:files) do
          [ "/rails/root/app/models/mongoid/behaviour.rb" ]
        end

        before do
          Dir.expects(:glob).with("/rails/root/app/models/**/*.rb").returns(files)
        end

        it "requires the models by subdirectory and basename" do
          Rails::Mongoid.expects(:load_model).with("mongoid/behaviour")
          Rails::Mongoid.preload_models(app)
        end
      end
    end
  end

  describe ".load_models" do

    let(:app) do
      stub(:config => config)
    end

    let(:config) do
      stub(:paths => paths)
    end

    let(:paths) do
      { "app/models" => [ "/rails/root/app/models" ] }
    end

    context "even when preload models config is false" do

      let(:files) do
        [
          "/rails/root/app/models/user.rb",
          "/rails/root/app/models/address.rb"
        ]
      end

      before(:all) do
        Mongoid.preload_models = false
        Dir.stubs(:glob).with("/rails/root/app/models/**/*.rb").returns(files)
      end

      it "loads all models" do
        Rails::Mongoid.expects(:load_model).with("address")
        Rails::Mongoid.expects(:load_model).with("user")
        Rails::Mongoid.load_models(app)
      end
    end
  end
end
