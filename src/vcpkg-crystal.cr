require "./result"
require "log"

# TODO: Write documentation for `Vcpkg::Crystal`
module Vcpkg::Crystal
  VERSION = "0.1.0"

  # TODO: Put your code here
end

require "json"
require "file_utils"

module Vcpkg
  Log = ::Log.for("vcpkg")

  def self.get_env(e : String)
    if env = ENV[e]?
      Ok.new(env)
    else
      Err.new("missing ENV #{e}")
    end
  end

  # Find the vcpkg root
  def self.find_vcpkg_root(cfg : Config) : Ok(Path) | Err(VcpkgNotFound)
    # prefer the setting from the use if there is one

    return Ok.new cfg.vcpkg_root.not_nil! if cfg.vcpkg_root

    # otherwise, use the setting from the environment
    if path = ENV["VCPKG_ROOT"]?
      return Ok.new Path.new(path)
    end

    # see if there is a per-user vcpkg tree that has been integrated into msbuild
    # using `vcpkg integrate install`
    if local_app_data = ENV["LOCALAPPDATA"]?
      vcpkg_user_targets_path = Path.new(local_app_data) / "vcpkg" / "vcpkg.user.targets"

      if File.file? vcpkg_user_targets_path
        begin
          File.each_line(vcpkg_user_targets_path) do |line|
            next unless line.includes?("Project=")

            if found = line.split(%<Project=">)[1].split('"')[0]
              if vcpkg_root = Path.new(found).parent.parent.parent.parent
                return Ok.new vcpkg_root
              else
                return Err.new(VcpkgNotFound["Could not find vcpkg root above #{found}"])
              end
            else
              return Err.new(VcpkgNotFound["Could not find vcpkg root in #{vcpkg_user_targets_path}"])
            end
          end
        rescue ex
          return Err.new(VcpkgNotFound["Parsing of #{vcpkg_user_targets_path} failed #{ex}"])
        end
      end
      return Err.new(VcpkgNotFound["Parsing of #{vcpkg_user_targets_path} failed no Project= in file"])
    end

    # walk up the directory structure and see if it is there
    if path = ENV["OUT_DIR"]?
      path = Path.new(path)

      while path.parent != path
        try_root = path / "vcpkg" / "vcpkg-root"

        if File.exists? try_root
          try_root = try_root.parent
          cv_cfg = try_root / "downloads" / "cargo-vcpkg.toml"
          return Ok.new try_root if File.exists? cv_cfg
        end
      end
    end

    Err.new(VcpkgNotFound["No vcpkg installation found. Set the VCPKG_ROOT environment variable or run 'vcpkg integrate install'"])
  end

  def self.validate_vcpkg_root(path : Path)
    vcpkg_root_path = path / ".vcpkg-root"
    if File.exists? vcpkg_root_path
      Ok.new(Void)
    else
      Err.new(VcpkgNotFound["Could not find vcpkg root at #{vcpkg_root_path}"])
    end
  end

  def self.valid_vcpkg_root?(path : Path)
    File.exists? path / ".vcpkg-root"
  end

  def self.find_vcpkg_target(cfg : Config, target_triplet : TargetTriplet)  : Ok(VcpkgTarget) | Err(VcpkgNotFound)
    vcpkg_root_result = find_vcpkg_root(cfg)
    case vcpkg_root_result
    when Err
       puts "returning err: typeof(vcpkg_root_result)"
       return vcpkg_root_result
    when Ok
    end
    vcpkg_root = vcpkg_root_result.unwrap
       

    base = if root = cfg.vcpkg_installed_root
             root
           else
             if env_root = ENV["VCPKG_INSTALLED_ROOT"]?
               Path[env_root]
             else
               vcpkg_root / "installed"
             end
           end

    # puts "typeof base after try: #{typeof(base)}"
    # puts "typeof vcpkg_root after try: #{typeof(vcpkg_root)}"

    status_path = base / "vcpkg"
    new_base = base / target_triplet.triplet
    lib_path = new_base / "lib"
    bin_path = new_base / "bin"
    include_path = new_base / "include"
    packages_path = vcpkg_root / "packages"

    return Ok.new(VcpkgTarget.new(
      lib_path: lib_path,
      bin_path: bin_path,
      include_path: include_path,
      status_path: status_path,
      packages_path: packages_path,
      target_triplet: target_triplet
    ))
    # "puts should get here"
  end

  def self.detect_target_triplet
    is_definitely_dynamic = ENV.has_key?("VCPKGRS_DYNAMIC")
    target = ENV.fetch("TARGET", "")
    is_static = ENV.fetch("CARGO_CFG_TARGET_FEATURE", "").includes?("crt-static")

    if target == "x86_64-apple-darwin"
      return Ok.new(TargetTriplet.new(triplet: "x64-osx", is_static: true, lib_suffix: "a", strip_lib_prefix: true))
    elsif target == "aarch64-apple-darwin"
      return Ok.new(TargetTriplet.new(triplet: "arm64-osx", is_static: true, lib_suffix: "a", strip_lib_prefix: true))
    elsif target == "x86_64-unknown-linux-gnu"
      return Ok.new(TargetTriplet.new(triplet: "x64-linux", is_static: true, lib_suffix: "a", strip_lib_prefix: true))
    elsif target == "aarch64-apple-ios"
      return Ok.new(TargetTriplet.new(triplet: "arm64-ios", is_static: true, lib_suffix: "a", strip_lib_prefix: true))
    elsif target.starts_with?("wasm32-")
      return Ok.new(TargetTriplet.new(triplet: "wasm32-emscripten", is_static: true, lib_suffix: "a", strip_lib_prefix: true))
    else
      if !target.includes?("-pc-windows-msvc")
        # Handle other cases or return an error
        return Err.new(NotMSVC["Unknown target triplet"])
      end
    end
    if target.starts_with?("x86_64-")
      if is_static
        Ok.new(TargetTriplet.new(triplet: "x64-windows-static", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      elsif is_definitely_dynamic
        Ok.new(TargetTriplet.new(triplet: "x64-windows", is_static: false, lib_suffix: "lib", strip_lib_prefix: false))
      else
        Ok.new(TargetTriplet.new(triplet: "x64-windows-static-md", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      end
    elsif target.starts_with?("aarch64-")
      if is_static
        Ok.new(TargetTriplet.new(triplet: "arm64-windows-static", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      elsif is_definitely_dynamic
        Ok.new(TargetTriplet.new(triplet: "arm64-windows", is_static: false, lib_suffix: "lib", strip_lib_prefix: false))
      else
        Ok.new(TargetTriplet.new(triplet: "arm64-windows-static-md", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      end
    else
      # everything else is x86
      if is_static
        Ok.new(TargetTriplet.new(triplet: "x86-windows-static", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      elsif is_definitely_dynamic
        Ok.new(TargetTriplet.new(triplet: "x86-windows", is_static: false, lib_suffix: "lib", strip_lib_prefix: false))
      else
        Ok.new(TargetTriplet.new(triplet: "x86-windows-static-md", is_static: true, lib_suffix: "lib", strip_lib_prefix: false))
      end
    end
  end

  # Configuration options for finding packages, setting up the tree and emitting metadata to cargo
  class Config
    # should the cargo metadata actually be emitted
    property cargo_metadata : Bool = false

    # should cargo:include= metadata be emitted (defaults to false)
    property emit_includes : Bool = false

    # .lib/.a files that must be found for probing to be considered successful
    property required_libs : Array(String) = [] of String

    # .dlls that must be found for probing to be considered successful
    property required_dlls : Array(String) = [] of String

    # should DLLs be copied to OUT_DIR? property copy_dlls : Bool = false
    property copy_dlls : Bool = false

    # override vcpkg installed path, regardless of both VCPKG_ROOT/installed and VCPKG_INSTALLED_ROOT environment variables
    property vcpkg_installed_root : Path? = nil

    # override VCPKG_ROOT environment variable
    property vcpkg_root : Path? = nil

    property target : TargetTriplet? = nil

    def initialize(@cargo_metadata = false, @emit_includes = false, @required_libs = [] of String, @required_dlls = [] of String, @copy_dlls = false, @vcpkg_installed_root : Path? = nil, @vcpkg_root : Path? = nil, @target : TargetTriplet? = nil)
    end

    # Deprecated in favor of the find_package function
    def self.probe_package(name : String) : Result(Library, Error)
      Config.new.probe(name)
    end
  end

  # Details of a package that was found
  class Library
    # Paths for the linker to search for static or import libraries
    property link_paths : Array(Path)
    # Paths to search at runtme to find DLLs
    property dll_paths : Array(Path)
    # Paths to include files
    property include_paths : Array(Path)
    # cargo: metadata lines
    property cargo_metadata : Array(String)
    # libraries found are static
    property is_static : Bool
    # DLLs found
    property found_dlls : Array(Path)
    # static libs or import libs found
    property found_libs : Array(Path)
    # link name of libraries found, this is useful to emit linker commands
    property found_names : Array(String)
    # ports that are providing the libraries to link to, in port link order
    property ports : Array(String)
    # the vcpkg triplet that has been selected
    property vcpkg_triplet : String

    def initialize(@link_paths : Array(Path), @dll_paths : Array(Path), @include_paths : Array(Path), @cargo_metadata : Array(String), @is_static : Bool, @found_dlls : Array(Path), @found_libs : Array(Path), @found_names : Array(String), @ports : Array(String), @vcpkg_triplet : String)
    end
  end

  struct TargetTriplet
    getter triplet : String
    getter is_static : Bool
    getter lib_suffix : String
    getter strip_lib_prefix : Bool

    def self.from(triplet : String) : TargetTriplet
      if triplet.contains?("windows")
        is_static = triplet.contains?("-static")
        new(triplet, is_static, "lib", false)
      else
        new(triplet, true, "a", true)
      end
    end

    def initialize(@triplet : String, @is_static : Bool, @lib_suffix : String, @strip_lib_prefix : Bool)
    end
  end

  # Paths and triple for chosen target
  struct VcpkgTarget
    property lib_path : Path
    property bin_path : Path
    property include_path : Path

    # directory containing the status file
    property status_path : Path
    # directory containing the install files per port
    property packages_path : Path

    # target specific settings
    property target_triplet : TargetTriplet

    def initialize(@lib_path, @bin_path, @include_path, @status_path, @packages_path, @target_triplet)
    end

    def link_name_for_lib(filename : Path | String)
      if target_triplet.strip_lib_prefix
        filename.to_s
      else
        filename.to_s
      end
    end
  end

  # Aborted because of a `VCPKGRS_NO_*` environment variable.
  #
  # Contains the name of the responsible environment variable.
  class Error < Exception
    def initialize(msg)
      super(msg)
    end

    def self.[](mess : String)
      new(mess)
    end
  end

  class VcpkgNotFound < Error
  end

  class NotMSVC < Error
  end
end
