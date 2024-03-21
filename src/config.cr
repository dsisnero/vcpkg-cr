module Vcpkg
  # Configuration options for finding packages, setting up the tree and emitting metadata to cargo
  class Config
    Log = ::Log.for(self)
    # should the cargo metadata actually be emitted
    property cargo_metadata : Bool = true

    # should cargo:include= metadata be emitted (defaults to false)
    property emit_includes : Bool = false

    # .lib/.a files that must be found for probing to be considered successful
    property required_libs : Array(String) = [] of String

    # .dlls that must be found for probing to be considered successful
    property required_dlls : Array(String) = [] of String

    # should DLLs be copied to OUT_DIR? property copy_dlls : Bool = false
    property copy_dlls : Bool = true

    # override vcpkg installed path, regardless of both VCPKG_ROOT/installed and VCPKG_INSTALLED_ROOT environment variables
    property vcpkg_installed_root : Path? = nil

    # override VCPKG_ROOT environment variable
    property vcpkg_root : Path? = nil

    property target : TargetTriplet? = nil

    def initialize(@cargo_metadata = true, @emit_includes = false, @required_libs = [] of String, @required_dlls = [] of String, @copy_dlls = true)
    end

    # Define the get_target_triplet method
    def get_target_triplet : Result
      if @target.nil?
        target = if triplet_str = ENV["VCPKGRS_TRIPLET"]?
                   Ok.new TargetTriplet.from(triplet_str)
                 else
                   Vcpkg.detect_target_triplet
                 end
        return target if target.err?
        @target = target.unwrap
      end

      Ok.new @target.dup
    end

    # Define the find_package method
    def find_package(port_name : String) : Result
      # Determine the target type
      msvc_target = get_target_triplet
      return msvc_target if msvc_target.err?
      msvc_target = msvc_target.unwrap.not_nil!

      # Bail out if requested to not try at all
      if ENV["VCPKGRS_DISABLE"]?
        return Err.new(DisabledByEnv.new "VCPKGRS_DISABLE")
      end

      # Bail out if requested to not try at all (old)
      if ENV["NO_VCPKG"]?
        return Err.new(DisabledByEnv.new "NO_VCPKG")
      end

      # Bail out if requested to skip this package
      abort_var_name = "VCPKGRS_NO_#{port_name}"
      if ENV[abort_var_name]?
        return Err.new(DisabledByEnv.new "#{abort_var_name}")
      end

      # Bail out if requested to skip this package (old)
      abort_var_name = "#{port_name}_NO_VCPKG"
      if ENV[abort_var_name]?
        return Err.new(DisabledByEnv.new "#{abort_var_name}")
      end

      vcpkg_target = Vcpkg.find_vcpkg_target(self, msvc_target).unwrap
      required_port_order = [] of String

      if @required_libs.empty?
        puts "Loading port for #{vcpkg_target}"

        ports = Port.load_ports(vcpkg_target).unwrap

        Log.info { "ports loaded\n#{ports.join("\n")}" }

        unless ports[port_name]
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
          puts "required_port_order #{required_port_order}"
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
              puts "path: #{path} dirname #{path.dirname} stem #{path.stem}"
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
      puts "required_ports #{required_ports}"
      puts "required_libs #{@required_libs}"
      puts "required_dlls #{@required_dlls}"

      if !vcpkg_target.target_triplet.is_static && !ENV["VCPKGRS_DYNAMIC"]?
        puts "RequiredEnvMissing VCPKGRS_DYNAMIC"
        return Err.new("RequiredEnvMissing VCPKGRS_DYNAMIC")
      end

      rlib = Library.new(vcpkg_target.target_triplet.is_static, vcpkg_target.target_triplet.triplet)

      if @emit_includes
        rlib.cargo_metadata << "cargo:include=#{vcpkg_target.include_path}"
      end

      rlib.include_paths << vcpkg_target.include_path
      rlib.cargo_metadata << "cargo:rustc-link-search=native=#{vcpkg_target.lib_path}"
      rlib.link_paths << vcpkg_target.lib_path

      unless vcpkg_target.target_triplet.is_static
        rlib.cargo_metadata << "cargo:rustc-link-search=native=#{vcpkg_target.bin_path}"
        rlib.dll_paths << vcpkg_target.bin_path
      end

      puts "rlib:\n#{rlib}\n**end of rlib**\n"
      rlib.ports = required_port_order

      did_emit = emit_libs(rlib, vcpkg_target)
      return did_emit if did_emit.err?

      did_copy = do_dll_copy(rlib) if @copy_dlls
      return Err.new(Error["Could not copy dlls"]) if did_copy.nil?
      return did_copy if did_copy.err?

      if @cargo_metadata
        rlib.cargo_metadata.each { |line| puts line }
      end

      Ok.new(rlib)
    end

    def emit_libs(rlib : Library, vcpkg_target : VcpkgTarget)
      self.required_libs.each do |required_lib|
        # Determine the link name based on whether the lib prefix should be stripped
        link_name = if vcpkg_target.target_triplet.strip_lib_prefix
                      required_lib.lchop("lib")
                    else
                      required_lib
                    end

        rlib.cargo_metadata << "cargo:rustc-link-lib=#{link_name}"
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

      Ok.new(Void)
    end

    def do_dll_copy(rlib : Library) : Result
      if target_dir = ENV["OUT_DIR"]?
        Dir.mkdir_p(target_dir)
        rlib.found_dlls.each do |file|
          begin
            dest_path = Path[target_dir] / file.basename
            File.copy(file, dest_path)
            puts "vcpkg build helper copied file #{file} to #{dest_path}"
          rescue
            return Err.new(LibNotFound.new("Can't copy file #{file} to #{dest_path}"))
          end
        end
        rlib.cargo_metadata << "cargo:rustc-link-search=native=#{target_dir}"
        rlib.cargo_metadata << "cargo:rustc-link-search=#{target_dir}"
      else
        return Err.new(LibNotFound.new("Unable to get env OUT_DIR"))
      end
      Ok.new(Void)
    rescue
      Err.new(LibNotFound.new("Can't copy file to dest_path"))
    end
  end
end
