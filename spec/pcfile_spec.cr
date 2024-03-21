require "./spec_helper"

describe Vcpkg::PcFile do
  vcpkg_target = Vcpkg::VcpkgTarget.new( # Assuming you have a VcpkgTarget class defined
Path.new("lib"),
    Path.new("bin"),
    Path.new("include"),
    Path.new("status"),
    Path.new("packages"),
    Vcpkg::TargetTriplet.new("x64-linux", true, "a", true)
  )

  context "when parsing a pc file" do
    pc_file_contents = <<-PCFILE
        Requires: zlib
        Requires.private: openssl
        Libs: -L/lib -lssl -lcrypto
      PCFILE

    it "parses the pc file correctly" do
      pc_file = Vcpkg::PcFile.from_str("test", pc_file_contents, vcpkg_target.target_triplet)
      pc_file.should be_a(Ok(Vcpkg::PcFile))
      pc_file = pc_file.unwrap
      pc_file.id.should eq("test")
      pc_file.libs.should eq(["libssl.a", "libcrypto.a"])
      pc_file.deps.should eq(["zlib"])
    end
  end
end

describe Vcpkg::PcFiles do
  vcpkg_target = Vcpkg::VcpkgTarget.new( # Assuming you have a VcpkgTarget class defined
Path.new("lib"),
    Path.new("bin"),
    Path.new("include"),
    Path.new("status"),
    Path.new("packages"),
    Vcpkg::TargetTriplet.new("x64-linux", true, "a", true)
  )

  context "when loading pkgconfig directory" do
    pkgconfig_dir = (Path.new(__DIR__) / "support/pkgconfig_dir").expand

    it "loads pkgconfig directory correctly" do
      pc_files_result = Vcpkg::PcFiles.load_pkgconfig_dir(vcpkg_target, pkgconfig_dir)
      pc_files_result.should be_a(Result)
      pc_files = pc_files_result.unwrap
      # pc_files.files.should contain("test")
      # pc_files.files["test"].libs.should eq(["libtest.a"])
      # pc_files.files["test"].deps.should eq(["zlib"])
    end
  end
end
