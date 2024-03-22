require "./spec_helper" # Assuming your Config class is in a file named config.cr

describe Vcpkg::Config do
  describe "#new" do
    it "initializes with default values" do
      config = Vcpkg::Config.new

      config.crystal_metadata.should be_true
      config.copy_dlls?.should be_true
      config.emit_includes.should be_false
      config.vcpkg_installed_root.should be_nil
      config.vcpkg_root.should be_nil
      config.target.should be_nil
    end
  end
  it "allows setting and getting crystal_metadata" do
    config = Vcpkg::Config.new
    config.crystal_metadata = true
    config.crystal_metadata.should eq(true)
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
    config.copy_dlls?.should eq(true)
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

  describe "#find_package" do
    it "finds the package" do
      cfg = Vcpkg::Config.new
      cfg.copy_dlls = false
      result = cfg.find_package("zlib")
      result.ok?.should be_true
      result.should be_a(Ok(Vcpkg::Library))
    end
    context "when set via cmd line" do
      it "workds correctly" do
        ENV["TARGET"] = "x86_64-pc-windows-msvc"
        ENV["VCPKGRS_DYNAMIC"]
        cfg = Vcpkg::Config.new
        cfg.copy_dlls = false
        cfg.crystal_metadata = false
        result = cfg.find_package("zlib")
        result.ok?.should be_true
        result.should be_a(Ok(Vcpkg::Library))
      end
    end
  end
end
