require "./spec_helper"

describe Vcpkg do
  # TODO: Write tests

  describe ".find_vcpkg_root" do
    context "when VCPKG_ROOT environment variable is set" do
      it "returns the path specified in VCPKG_ROOT" do
        with_env({"VCPKG_ROOT" => "/path/to/vcpkg"}) do
          Log.for("vcpkg").info { "about to call find_vcpkg_root" }
          config = Vcpkg::Config.new
          Vcpkg.find_vcpkg_root(config).should eq(Ok.new Path.new("/path/to/vcpkg"))
        end
      end
    end

    context "when VCPKG_ROOT environment variable is not set" do
      it "returns the correct path if it has been integrated by running vcpkg integrate install" do
        localappdata = (Path[__DIR__] / "appdata").to_s
        ENV.clear

        with_env({"LOCALAPPDATA" => localappdata}) do
          config = Vcpkg::Config.new
          Vcpkg.find_vcpkg_root(config).should eq Ok.new(Path["/path/to/vcpkg"])
        end
      end

      it "returns an error if vcpkg root cannot be found" do
        config = Vcpkg::Config.new
        result = Vcpkg.find_vcpkg_root(config)
        result.err?.should be_true
        result.unwrap_err.should be_a Vcpkg::VcpkgNotFound
        # result.unpack_err.message .should eq(Err.new(Vcpkg::VcpkgNotFound["No vcpkg installation found. Set the VCPKG_ROOT environment variable or run 'vcpkg integrate install'"]))
      end
    end
  end
  describe "find_vcpkg_target" do
    it "doesn't error" do
      ENV["TARGET"] = "x86_64-pc-windows-msvc"
      ENV["VCPKG_ROOT"] = "c:/windows_home/vcpkg"
      cfg = Vcpkg::Config.new
      target_triplet = Vcpkg.detect_target_triplet
      if target_triplet.ok?
        result = Vcpkg.find_vcpkg_target(cfg, target_triplet.unwrap)
        result.ok?.should be_true
        result = result.unwrap
        # result.lib_path.should eq(Path["lib"])
      else
        puts "error in find_vcpkg target #{target_triplet}"
      end
    end

    it "uses config installed root" do
      ENV["TARGET"] = "x86_64-pc-windows-msvc"
      ENV["VCPKG_ROOT"] = "c:/windows_home/vcpkg"
      cfg = Vcpkg::Config.new
      target_triplet = Vcpkg.detect_target_triplet.unwrap
      cfg.vcpkg_installed_root = Path["/path/to/root"]
      res = Vcpkg.find_vcpkg_target(cfg, target_triplet)
      pp res
      res.ok?.should be_true
      result = res.unwrap
      # result.lib_path.should eq Path["/path/to/root"] / "lib"
    end
  end
  describe ".detect_target_triplet" do
    context "when target is x86_64-apple-darwin" do
      it "returns correct TargetTriplet" do
        ENV["TARGET"] = "x86_64-apple-darwin"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_true

        triplet = result.unwrap
        triplet.triplet.should eq("x64-osx")
        triplet.is_static.should eq(true)
        triplet.lib_suffix.should eq("a")
        triplet.strip_lib_prefix.should eq(true)
      end
    end

    context "when target is aarch64-apple-darwin" do
      it "returns correct TargetTriplet" do
        ENV["TARGET"] = "aarch64-apple-darwin"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_true

        triplet = result.unwrap
        triplet.triplet.should eq("arm64-osx")
        triplet.is_static.should eq(true)
        triplet.lib_suffix.should eq("a")
        triplet.strip_lib_prefix.should eq(true)
      end
    end

    context "when target is x86_64-unknown-linux-gnu" do
      it "returns correct TargetTriplet" do
        ENV["TARGET"] = "x86_64-unknown-linux-gnu"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_true

        triplet = result.unwrap
        triplet.triplet.should eq("x64-linux")
        triplet.is_static.should eq(true)
        triplet.lib_suffix.should eq("a")
        triplet.strip_lib_prefix.should eq(true)
      end
    end

    context "when target is aarch64-apple-ios" do
      it "returns correct TargetTriplet" do
        ENV["TARGET"] = "aarch64-apple-ios"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_true

        triplet = result.unwrap
        triplet.triplet.should eq("arm64-ios")
        triplet.is_static.should eq(true)
        triplet.lib_suffix.should eq("a")
        triplet.strip_lib_prefix.should eq(true)
      end
    end

    context "when target starts with wasm32-" do
      it "returns correct TargetTriplet" do
        ENV["TARGET"] = "wasm32-unknown-unknown"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_true

        triplet = result.unwrap
        triplet.triplet.should eq("wasm32-emscripten")
        triplet.is_static.should eq(true)
        triplet.lib_suffix.should eq("a")
        triplet.strip_lib_prefix.should eq(true)
      end
    end

    context "when target does not include -pc-windows-msvc" do
      context "when is_static is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "x86_64-linux-gnu"
          ENV["CARGO_CFG_TARGET_FEATURE"] = "crt-static"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end

      context "when is_definitely_dynamic is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "x86_64-linux-gnu"
          ENV["VCPKGRS_DYNAMIC"] = "1"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end
    end

    context "when target does not include -pc-windows-msvc and starts with aarch64-" do
      context "when is_static is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "aarch64-linux-gnu"
          ENV["CARGO_CFG_TARGET_FEATURE"] = "crt-static"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end

      context "when is_definitely_dynamic is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "aarch64-linux-gnu"
          ENV["VCPKGRS_DYNAMIC"] = "1"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end

      context "when neither is_static nor is_definitely_dynamic is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "aarch64-linux-gnu"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end
    end

    context "when target does not include -pc-windows-msvc and starts with x86_" do
      context "when is_static is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "x86_64-linux-gnu"
          ENV["CARGO_CFG_TARGET_FEATURE"] = "crt-static"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end

      context "when is_definitely_dynamic is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "x86_64-linux-gnu"
          ENV["VCPKGRS_DYNAMIC"] = "1"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end

      context "when neither is_static nor is_definitely_dynamic is true" do
        it "returns error Vcpkg::NotMSVC" do
          ENV["TARGET"] = "x86_64-linux-gnu"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_false
          result.unwrap_err.should be_a Vcpkg::NotMSVC
        end
      end
    end

    context "when target does not include -pc-windows-msvc and starts with unknown" do
      it "returns error Vcpkg::NotMSVC" do
        ENV["TARGET"] = "unknown-linux-gnu"
        result = Vcpkg.detect_target_triplet
        result.ok?.should be_false
        result.unwrap_err.should be_a Vcpkg::NotMSVC
        result = Vcpkg.detect_target_triplet
        result.err?.should be_true

        err = result.unwrap_err
        err.should be_a(Vcpkg::NotMSVC)
        err.message.should eq("Unknown target triplet")
      end
    end

    context "when target includes -pc-windows-msvc" do
      context "when starts with x86_64" do
        context "when is_static is true" do
          it "returns x65-windows-static" do
            ENV.clear
            ENV["TARGET"] = "x86_64-pc-windows-msvc"
            ENV["CARGO_CFG_TARGET_FEATURE"] = "crt-static"
            result = Vcpkg.detect_target_triplet
            result.ok?.should be_true
            result = result.unwrap
            result.should be_a Vcpkg::TargetTriplet
            result.triplet.should eq("x64-windows-static")
            result.lib_suffix.should eq("lib")
          end
        end

        context "is_static is false" do
          ENV["TARGET"] = "x86_64-pc-windows-msvc"
          ENV["CARGO_CFG_TARGET_FEATURE"] = "non-static"
          ENV["VCPKGRS_DYNAMIC"] = "on"
          result = Vcpkg.detect_target_triplet
          result.ok?.should be_true
          result = result.unwrap
          result.should be_a Vcpkg::TargetTriplet
          result.triplet.should eq("x64-windows")
          result.lib_suffix.should eq("lib")
          result.is_static.should be_false
        end
      end
    end

    context "when target is empty" do
      it "returns error Vcpkg::NotMSVC" do
        ENV["TARGET"] = nil
        result = Vcpkg.detect_target_triplet
        result.err?.should be_true

        err = result.unwrap_err
        err.should be_a(Vcpkg::NotMSVC)
        err.message.should eq("Unknown target triplet")
      end
    end
  end
end
