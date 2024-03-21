require "./spec_helper" # Assuming your Config class is in a file named config.cr

describe Vcpkg::Config do
  describe "#new" do
    it "initializes with default values" do
      config = Vcpkg::Config.new

      config.cargo_metadata.should be_true
      config.copy_dlls.should be_true
      config.emit_includes.should be_false
      config.vcpkg_installed_root.should be_nil
      config.vcpkg_root.should be_nil
      config.target.should be_nil
    end
  end
  it "allows setting and getting cargo_metadata" do
    config = Vcpkg::Config.new
    config.cargo_metadata = true
    config.cargo_metadata.should eq(true)
  end

  it "allows setting and getting emit_includes" do
    config = Vcpkg::Config.new
    config.emit_includes = true
    config.emit_includes.should eq(true)
  end

  it "allows setting and getting required_libs" do
    config = Vcpkg::Config.new
    config.required_libs = ["lib1", "lib2"]
    config.required_libs.should eq(["lib1", "lib2"])
  end

  it "allows setting and getting required_dlls" do
    config = Vcpkg::Config.new
    config.required_dlls = ["dll1", "dll2"]
    config.required_dlls.should eq(["dll1", "dll2"])
  end

  it "allows setting and getting copy_dlls" do
    config = Vcpkg::Config.new
    config.copy_dlls = true
    config.copy_dlls.should eq(true)
  end

  it "allows setting and getting vcpkg_installed_root" do
    config = Vcpkg::Config.new
    config.vcpkg_installed_root = Path.new("/some/path")
    config.vcpkg_installed_root.should eq(Path.new("/some/path"))
  end

  it "allows setting and getting vcpkg_root" do
    config = Vcpkg::Config.new
    config.vcpkg_root = Path.new("/another/path")
    config.vcpkg_root.should eq(Path.new("/another/path"))
  end

  it "allows setting and getting target" do
    triplet = Vcpkg::TargetTriplet.new("x86_64-linux", true, "a", true)
    config = Vcpkg::Config.new
    config.target = triplet
    config.target.should eq(triplet)
  end

  pending "#get_target_triplet" do
    it "returns the target triplet if set in config" do
      config = Vcpkg::Config.new
      config.get_target_triplet.should eq("x86_64-linux-gnu")
    end
  end

  it "finds the package" do
    ENV["OUT_DIR"] = (Path.new(__DIR__) / "out").to_s
    config = Vcpkg::Config.new
    result = config.find_package("zlib")
    puts result
  end
end
