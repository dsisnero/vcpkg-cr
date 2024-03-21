require "./error"
require "./result"
require "./library"

require "./pcfile"
require "./config"
require "./port"
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

  def self.find_package(package : String) : Result
    Config.new.find_package(package)
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
          cv_cfg = try_root / "downloads" / "crystal-vcpkg.toml"
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

  def self.find_vcpkg_target(cfg : Config, target_triplet : TargetTriplet) : Ok(VcpkgTarget) | Err(VcpkgNotFound)
    vcpkg_root_result = find_vcpkg_root(cfg)
    case vcpkg_root_result
    when Err
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

    status_path = base / "vcpkg"
    new_base = base / target_triplet.triplet
    lib_path = new_base / "lib"
    bin_path = new_base / "bin"
    include_path = new_base / "include"
    packages_path = vcpkg_root / "packages"

    Ok.new(VcpkgTarget.new(
      lib_path: lib_path,
      bin_path: bin_path,
      include_path: include_path,
      status_path: status_path,
      packages_path: packages_path,
      target_triplet: target_triplet
    ))
  end

  def self.detect_target_triplet
    is_definitely_dynamic = ENV.has_key?("VCPKGRS_DYNAMIC")
    target = ENV.fetch("TARGET", "")
    is_static = ENV.fetch("CRYSTAL_CFG_TARGET_FEATURE", "").includes?("crt-static")

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

  def self.envify(name : String)
    name.upcase.gsub("-", "_")
  end

  def self.load_ports(target : VcpkgTarget) : Hash(String, Port)
    ports = {} of String => Port
    port_info = [] of Hash(String, String)

    # load the main status file
    status_filename = target.status_path / "status"
    load_port_file(status_filename, port_info)

    # load updates to the status file
    status_update_dir = File.join(target.status_path, "updates")
    paths = Dir.glob(File.join(status_update_dir, "*"))
    paths.each { |path| load_port_file(path, port_info) }

    # Process port info
    seen_names = {} of Tuple(String, String, String) => Hash(String, String)
    port_info.each do |current|
      name = current["Package"]
      arch = current["Architecture"]
      feature = current["Feature"]

      if name && arch
        seen_names[{name, arch, feature}] = current
      end
    end

    seen_names.each do |(name, arch, feature), current|
      if arch == target.target_triplet.triplet
        if current["Status"].ends_with?(" installed")
          version = current["Version"]
          deps = current["Depends"].to_s.split(", ")
          if version
            begin
              dlls, libs = load_port_manifest(target.status_path, name, version, target)
              port = Port.new(dlls: dlls, libs: libs, deps: deps)
              ports[name] = port
            rescue e
              puts "Error loading port manifest for #{name}: #{e.message}"
            end
          elsif feature
            if ports.has_key?(name)
              ports[name].deps += deps
            else
              puts "Found a feature that had no corresponding port :-"
              puts "Current: #{current}"
            end
          else
            puts "Didn't know how to deal with status file entry :-"
            puts "#{current}"
          end
        end
      end
    end

    ports
  end
end

# Aborted because of a `VCPKGRS_NO_*` environment variable.
#
# Contains the name of the responsible environment variable.
