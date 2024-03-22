# A build dependency for Crystal libraries to find libraries in a
# [Vcpkg](https://github.com/microsoft/vcpkg) tree
#
# From a Vcpkg package name
# this build helper will emit crystal metadata to link it and it's dependencies
# (excluding system libraries, which it does not determine).
#
# The simplest possible usage looks like this :-
#
# ```rust,no_run
# // build.rs
# vcpkg::find_package("libssh2").unwrap();
# ```
#
# The crystal metadata that is emitted can be changed like this :-
#
# ```rust,no_run
# // build.rs
# vcpkg::Config::new()
#     .emit_includes(true)
#     .find_package("zlib").unwrap();
# ```
#
# If the search was successful all appropriate Crystal metadata will be printed
# to stdout.
#
# # Static vs. dynamic linking
# ## Linux and Mac
# At this time, vcpkg has a single triplet on macOS and Linux, which builds
# static link versions of libraries. This triplet works well with Rust. It is also possible
# to select a custom triplet using the `VCPKGRS_TRIPLET` environment variable.
# ## Windows
# On Windows there are three
# configurations that are supported for 64-bit builds and another three for 32-bit.
# The default 64-bit configuration is `x64-windows-static-md` which is a
# [community supported](https://github.com/microsoft/vcpkg/blob/master/docs/users/triplets.md#community-triplets)
# configuration that is a good match for Rust - dynamically linking to the C runtime,
# and statically linking to the packages in vcpkg.
#
# Another option is to build a fully static
# binary using `RUSTFLAGS=-Ctarget-feature=+crt-static`. This will link to libraries built
# with vcpkg triplet `x64-windows-static`.
#
# For dynamic linking, set `VCPKGRS_DYNAMIC=1` in the
# environment. This will link to libraries built with vcpkg triplet `x64-windows`. If `VCPKGRS_DYNAMIC` is set, `crystal install` will
# generate dynamically linked binaries, in which case you will have to arrange for
# dlls from your Vcpkg installation to be available in your path.
#
# ## WASM 32
#
# At this time, vcpkg has a single triplet for wasm32, wasm32-emscripten,
# while rust has several targets for wasm32.
# Currently all of these targets are mapped to wasm32-emscripten triplet.
#
# You can open an [issue](https://github.com/mcgoo/vcpkg-rs/issue)
# if more wasm32 triplets come to vcpkg.
# And just like other target, it is possibleto select a custom triplet
# using the `VCPKGRS_TRIPLET` environment variable.
#
# # Environment variables
#
# A number of environment variables are available to globally configure which
# libraries are selected.
#
# * `VCPKG_ROOT` - Set the directory to look in for a vcpkg root. If
# it is not set, vcpkg will use the user-wide installation if one has been
# set up with `vcpkg integrate install`, and check the crate source and target
# to see if a vcpkg tree has been created by [crystal-vcpkg](https://crates.io/crates/crystal-vcpkg).
#
# * `VCPKG_INSTALLED_ROOT` - Set the directory for the vcpkg installed directory. Corresponding to
# `--x-install-root` flag in `vcpkg install` command.
# A typical use case is to set it to `vcpkg_installed` directory under build directory
# to adapt [manifest mode of vcpkg](https://learn.microsoft.com/en-us/vcpkg/users/manifests).
# If set, this will override the default value of `VCPKG_ROOT/installed`.
#
# * `VCPKGRS_TRIPLET` - Use this to override vcpkg-rs' default triplet selection with your own.
# This is how to select a custom vcpkg triplet.
#
# * `VCPKGRS_NO_FOO` - if set, vcpkg-rs will not attempt to find the
# library named `foo`.
#
# * `VCPKGRS_DISABLE` - if set, vcpkg-rs will not attempt to find any libraries.
#
# * `VCPKGRS_DYNAMIC` - if set, vcpkg-rs will link to DLL builds of ports.
# # Related tools
# ## crystal vcpkg
# [`crystal vcpkg`](https://crates.io/crates/crystal-vcpkg) can fetch and build a vcpkg installation of
# required packages from scratch. It merges package requirements specified in the `Crystal.toml` of
# crates in the dependency tree.
# ## vcpkg_cli
# There is also a rudimentary companion crate, `vcpkg_cli` that allows testing of environment
# and flag combinations.
#
# ```Batchfile
# C:\src> vcpkg_cli probe -l static mysqlclient
# Found library mysqlclient
# Include paths:
#         C:\src\[..]\vcpkg\installed\x64-windows-static\include
# Library paths:
#         C:\src\[..]\vcpkg\installed\x64-windows-static\lib
# Crystal metadata:
#         crystal:rustc-link-search=native=C:\src\[..]\vcpkg\installed\x64-windows-static\lib
#         crystal:rustc-link-lib=static=mysqlclient
# ```

# The CI will test vcpkg-rs on 1.12 because that is how far back vcpkg-rs 0.2 tries to be
# compatible (was actually 1.10 see #29).  This was originally based on how far back
# rust-openssl's openssl-sys was backward compatible when this crate originally released.
#
# This will likely get bumped by the next major release.

module Vcpkg
  alias Error = VcpkgNotFound | NotMSVC | VcpkgInstallation | DisabledByEnv | LibNotFound

  # Configuration options for finding packages, setting up the tree and emitting metadata to crystal
  class Config
    Log = ::Log.for(self)
    # should the crystal metadata actually be emitted
    property crystal_metadata : Bool = true

    # should crystal:include= metadata be emitted (defaults to false)
    property emit_includes : Bool = false

    # .lib/.a files that must be found for probing to be considered successful
    property required_libs : Array(String) = [] of String

    # .dlls that must be found for probing to be considered successful
    property required_dlls : Array(String) = [] of String

    # should DLLs be copied to OUT_DIR? property copy_dlls : Bool = false
    property? copy_dlls : Bool = true

    # override vcpkg installed path, regardless of both VCPKG_ROOT/installed and VCPKG_INSTALLED_ROOT environment variables
    property vcpkg_installed_root : Path? = nil

    # override VCPKG_ROOT environment variable
    property vcpkg_root : Path? = nil

    property target : TargetTriplet? = nil

    def initialize(@crystal_metadata = true, @emit_includes = false, @required_libs = [] of String, @required_dlls = [] of String, @copy_dlls = true)
    end

    # Define the get_target_triplet method
    def get_target_triplet : Ok(TargetTriplet) | Err(NotMSVC)
      if @target.nil?
        target = if triplet_str = ENV["VCPKGRS_TRIPLET"]?
                   TargetTriplet.from(triplet_str)
                 else
                   try!(Vcpkg.detect_target_triplet)
                 end
        @target = target.not_nil!
      end

      Ok.new target.not_nil!.dup
    end

    def envify(name : String)
      name.upcase.gsub("-", "_")
    end

    # Define the find_package method
    def find_package(port_name : String)
      # Determine the target type
      msvc_target = try!(get_target_triplet)

      # Bail out if requested to not try at all
      if ENV["VCPKGRS_DISABLE"]?
        return Err.new(DisabledByEnv.new "VCPKGRS_DISABLE")
      end

      # Bail out if requested to not try at all (old)
      if ENV["NO_VCPKG"]?
        return Err.new(DisabledByEnv.new "NO_VCPKG")
      end

      # Bail out if requested to skip this package
      abort_var_name = "VCPKGRS_NO_#{envify(port_name)}"
      if ENV[abort_var_name]?
        return Err.new(DisabledByEnv.new "#{abort_var_name}")
      end

      # Bail out if requested to skip this package (old)
      abort_var_name = "#{envify(port_name)}_NO_VCPKG"
      if ENV[abort_var_name]?
        return Err.new(DisabledByEnv.new "#{abort_var_name}")
      end

      vcpkg_target = try!(Vcpkg.find_vcpkg_target(self, msvc_target))
      required_port_order = [] of String

      if @required_libs.empty?
        Log.debug { "loading ports for vcpkg_target #{vcpkg_target}" }
        ports = try!(Port.load_ports(vcpkg_target))

        Log.debug { "ports loaded\n#{ports.join("\n")}" }

        unless ports[port_name]?
          return Err.new(LibNotFound.new("LibNotFound package #{port_name} is not installed for vcpkg triplet #{vcpkg_target.target_triplet.triplet}"))
        end

        required_ports = {} of String => Port
        ports_to_scan = [port_name]

        until ports_to_scan.empty?
          port_name = ports_to_scan.pop

          next if required_ports.has_key?(port_name)

          if port = ports[port_name]?
            port.deps.each { |dep| ports_to_scan.push(dep) }
            required_ports[port_name] = port
            required_port_order.delete(port_name)
            required_port_order.push(port_name)
          else
            # what?
          end
        end

        if @required_libs.empty?
          required_port_order.each do |port_name|
            port = required_ports[port_name]
            port.libs.each do |s|
              path = Path.new(s)
              dirname = path.dirname
              if dirname
                @required_libs << "#{dirname}/#{path.stem}"
              else
                @required_libs << path.stem
              end
            end
            port.dlls.each do |s|
              path = Path.new(s)
              dirname = path.dirname
              if dirname
                @required_dlls << "#{dirname}/#{path.stem}"
              else
                @required_dlls << path.stem
              end
            end
          end
        end
      end

      if !vcpkg_target.target_triplet.is_static && !ENV["VCPKGRS_DYNAMIC"]?
        return Err.new(RequiredEnvMissing.new("VCPKGRS_DYNAMIC"))
      end

      rlib = Library.new(vcpkg_target.target_triplet.is_static, vcpkg_target.target_triplet.triplet)

      if @emit_includes
        rlib.crystal_metadata << "crystal:include=#{vcpkg_target.include_path}"
      end

      rlib.include_paths << vcpkg_target.include_path
      rlib.crystal_metadata << "crystal:rustc-link-search=native=#{vcpkg_target.lib_path}"
      rlib.link_paths << vcpkg_target.lib_path

      unless vcpkg_target.target_triplet.is_static
        rlib.crystal_metadata << "crystal:rustc-link-search=native=#{vcpkg_target.bin_path}"
        rlib.dll_paths << vcpkg_target.bin_path
      end

      rlib.ports = required_port_order

      _bogus = try!(emit_libs(rlib, vcpkg_target))
      _bogus = nil

      if copy_dlls?
        bogus = try!(do_dll_copy(rlib))
      end
      # return did_copy if did_copy.err?

      if @crystal_metadata
        rlib.crystal_metadata.each { |line| puts line }
      end
      Log.debug { "rlib type #{typeof(rlib)}" }

      Ok.new(rlib.as(Library))
    end

    def emit_libs(rlib : Library, vcpkg_target : VcpkgTarget) : Ok(Int32) | Err(LibNotFound)
      self.required_libs.each do |required_lib|
        # Determine the link name based on whether the lib prefix should be stripped
        link_name = if vcpkg_target.target_triplet.strip_lib_prefix
                      required_lib.lchop("lib")
                    else
                      required_lib
                    end

        rlib.crystal_metadata << "crystal:rustc-link-lib=#{link_name}"
        rlib.found_names << link_name

        # Verify that the library exists
        lib_location = vcpkg_target.lib_path / "#{required_lib}.#{vcpkg_target.target_triplet.lib_suffix}"
        unless File.exists? lib_location
          return Err.new(LibNotFound.new(lib_location.to_s))
        end
        rlib.found_libs << lib_location
      end

      unless vcpkg_target.target_triplet.is_static
        self.required_dlls.each do |required_dll|
          dll_location = vcpkg_target.bin_path / "#{required_dll}.dll"

          # Verify that the DLL exists
          unless File.exists? dll_location
            return Err.new(LibNotFound.new(dll_location.to_s))
          end
          rlib.found_dlls << dll_location
        end
      end

      Ok.new(0)
    end

    def do_dll_copy(rlib : Library) : Ok(Int32) | Err(LibNotFound)
      if target_dir = ENV["OUT_DIR"]?
        rlib.found_dlls.each do |file|
          dest_path = Path[target_dir] / file.basename
          File.copy(file, dest_path)
          puts "vcpkg build helper copied file #{file} to #{dest_path}"
        end
        rlib.crystal_metadata << "crystal:rustc-link-search=native=#{target_dir}"
        rlib.crystal_metadata << "crystal:rustc-link-search=#{target_dir}"
        Ok.new(0)
      else
        Err.new(LibNotFound["Cannot copy dll unless env OUT_DIR is set"])
      end
    rescue e
      Log.error { "failed to copy dlls #{e}" }
      Err.new(LibNotFound.new("Can't copy file to dest_path"))
    end

    def do_dll_copy2(rlib : Library) : Ok(Nil) | Err(LibNotFound)
      return Err.new(LibNotFound["Cannot copy dll unless env OUT_DIR is set"]) unless ENV.has_key?("OUT_DIR")
      target_dir = ENV["OUT_DIR"]
      rlib.found_dlls.each do |file|
        dest_path = Path[target_dir] / file.basename
        File.copy(file, dest_path)
        puts "vcpkg build helper copied file #{file} to #{dest_path}"
      end
      rlib.crystal_metadata << "crystal:rustc-link-search=native=#{target_dir}"
      rlib.crystal_metadata << "crystal:rustc-link-search=#{target_dir}"
      Ok.new(0)
    rescue e
      Err.new(LibNotFound.new("Can't copy file to dest_path"))
    end

    # Override the name of the library to look for if it differs from the package name.
    #
    # It should not be necessary to use `lib_name` anymore. Calling `find_package` with a package name
    # will result in the correct library names.
    # This may be called more than once if multiple libs are required.
    # All libs must be found for the probe to succeed. `.probe()` must
    # be run with a different configuration to look for libraries under one of several names.
    # `.libname("ssleay32")` will look for ssleay32.lib and also ssleay32.dll if
    # dynamic linking is selected.
    def lib_name(lib_stem : String)
      self.required_libs.<< lib_stem
      self.required_dlls.<< lib_stem
      self
    end

    # Override the name of the library to look for if it differs from the package name.
    #
    # It should not be necessary to use `lib_names` anymore. Calling `find_package` with a package name
    # will result in the correct library names.
    # This may be called more than once if multiple libs are required.
    # All libs must be found for the probe to succeed. `.probe()` must
    # be run with a different configuration to look for libraries under one of several names.
    # `.lib_names("libcurl_imp","curl")` will look for libcurl_imp.lib and also curl.dll if
    # dynamic linking is selected.
    def lib_names(lib_stem : String, dll_stem : String)
      self.required_libs lib_stem
      self.required_dlls dll_stem
      self
    end
  end
end
