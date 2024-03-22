module Vcpkg
  struct Port
    Log = ::Log.for(self)
    # dlls if any
    property dlls : Array(String) = [] of String

    # libs (static or import)
    property libs : Array(String) = [] of String

    # ports that this port depends on
    property deps : Array(String) = [] of String

    def initialize(@dlls = [] of String, @libs = [] of String, @deps = [] of String)
    end

    def self.load_port_manifest(
      path : Path,
      port : String,
      version : String,
      vcpkg_target : VcpkgTarget
    ) : Result
      manifest_file = path.join("info", "#{port}_#{version}_#{vcpkg_target.target_triplet.triplet}.list")

      dlls = [] of String
      libs = [] of String

      f = File.open(manifest_file) do |file|
        file

        file.each_line do |line|
          file_path = Path.new(line.chomp)

          if (dll = file_path.relative_to(Path[vcpkg_target.target_triplet.triplet.to_s] / "bin")) &&
             dll.extension == ".dll" && dll.to_s.split.size == 1
            dlls << dll.to_s
          elsif (rlib = file_path.relative_to(vcpkg_target.target_triplet.triplet.to_s + "/lib")) &&
                rlib.extension == vcpkg_target.target_triplet.lib_suffix && rlib.to_s.split == 1
            if link_name = vcpkg_target.link_name_for_lib(rlib)
              libs << link_name
            end
          end
        end

        # Load .pc files for hints about intra-port library ordering.
        pkg_config_prefix = vcpkg_target.packages_path.join("#{port}_#{vcpkg_target.target_triplet.triplet}").join("lib").join("pkgconfig")
        # Try loading the pc files, if they are present. Not all ports have pkgconfig.
        if (pc_files_result = PcFiles.load_pkgconfig_dir(vcpkg_target, pkg_config_prefix)).ok?
          # Use the .pc file data to potentially sort the libs to the correct order.
          libs = pc_files_result.unwrap.fix_ordering(libs)
        end

        Ok.new({dlls, libs})
      rescue
        return Err.new Error.new("Could not open port manifest file #{manifest_file}")
      end
    end

    def self.load_ports(target : VcpkgTarget) : Result
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
      seen_names = {} of Tuple(String, String, String?) => Hash(String, String)
      port_info.each do |current|
        name = current["Package"]
        arch = current["Architecture"]
        feature = current["Feature"]?

        if name && arch
          seen_names[{name, arch, feature}] = current
        end
      end

      seen_names.each do |(name, arch, feature), current|
        if arch == target.target_triplet.triplet
          if current["Status"].ends_with?(" installed")
            version = current["Version"]?
            deps = current.fetch("Depends", "").split(", ")
            if version
              begin
                port_result = load_port_manifest(target.status_path, name, version, target)
                return port_result.as Err if port_result.err?
                dlls, libs = port_result.unwrap
                port = Port.new(dlls: dlls, libs: libs, deps: deps)
                ports[name] = port
              rescue e
                Log.error { "Error loading port manifest for #{name}: #{e.message}" }
              end
            elsif feature
              if ports.has_key?(name)
                ports[name].deps += deps
              else
                Log.error { "Found a feature that had no corresponding port :-" }
                Log.error { "Current: #{current}" }
              end
            else
              Log.error { "Didn't know how to deal with status file entry :-" }
              Log.error { "#{current}" }
            end
          end
        end
      end

      Ok.new ports
    end

    def self.load_port_file(filename : String | Path, port_info : Array(Hash(String, String)))
      current = Hash(String, String).new
      lines = File.read_lines(filename)
      lines.each do |line|
        parts = line.split(": ", 2)
        if parts.size == 2
          current[parts[0].strip] = parts[1].strip
        elsif line.empty?
          # end of section
          port_info << current.dup
          current.clear
        else
          # ignore all extension lines of the form
          #
          # Description: a package with a
          #   very long description
          #
          # the description key is not used so this is harmless but
          # this will eat extension lines for any multiline key which
          # could become an issue in future
        end
      end
      if !current.empty?
        port_info.push(current)
      end
      Ok(Void)
    rescue e
    end
  end
end
