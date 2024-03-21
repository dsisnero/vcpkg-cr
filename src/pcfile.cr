# Paths and triple for chosen target
module Vcpkg
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

  struct TargetTriplet
    getter triplet : String
    getter is_static : Bool
    getter lib_suffix : String
    getter strip_lib_prefix : Bool

    def self.from(triplet : String) : TargetTriplet
      if triplet.includes?("windows")
        is_static = triplet.includes?("-static")
        new(triplet, is_static, "lib", false)
      else
        new(triplet, true, "a", true)
      end
    end

    def initialize(@triplet : String, @is_static : Bool, @lib_suffix : String, @strip_lib_prefix : Bool)
    end
  end

  struct PcFile
    Log = ::Log.for("pcfile")
    property id : String
    property libs : Array(String) = [] of String
    property deps : Array(String) = [] of String

    def initialize(@id, @libs, @deps)
    end

    def self.parse_pc_file(vcpkg_target : VcpkgTarget, path : Path | String) : Result
      path = Path[path]
      id = path.basename.to_s.split(".").first
      pc_file_contents = File.read(path)

      from_str(id, pc_file_contents, vcpkg_target.target_triplet)
    rescue error
      Err.new(VcpkgInstallation["VcpkgInstallation Couldn't open #{path}"])
    end

    def self.from_str(id : String, s : String, target_triplet : TargetTriplet)
      libs = [] of String
      deps = [] of String

      s.each_line do |line|
        line = line.lstrip
        if line.starts_with?("Requires:")
          requires_args = line.split(":").last.split(" ").flat_map(&.split(",")).reject(&.empty?)
          requires_args.each do |dep|
            if dep.index("=") || dep.index("<") || dep.index(">")
              next
            end
            deps << dep
          end
        elsif line.starts_with?("Libs:")
          lib_flags = line.split(":").last.split(" ").reject(&.empty?)
          lib_flags.each do |lib_flag|
            if lib_flag.starts_with?("-l")
              lib_name = if target_triplet.strip_lib_prefix
                           "lib" + lib_flag.lchop("-l") + "." + target_triplet.lib_suffix
                         else
                           lib_flag.lchop("-l") + "." + target_triplet.lib_suffix
                         end
              libs << lib_name
            end
          end
        end
      end
      Ok.new(new(id, libs, deps))
    end
  end

  struct PcFiles
    getter files : Hash(String, PcFile) = {} of String => PcFile

    def initialize(@files)
    end

    def self.load_pkgconfig_dir(vcpkg_target : VcpkgTarget, path : Path) : Result
      files = {} of String => PcFile
      Dir.each_child(path) do |file|
        fpath = (path / file).expand

        next unless fpath.extension == ".pc"
        pc_file_result = PcFile.parse_pc_file(vcpkg_target, fpath)
        return pc_file_result.as Err if pc_file_result.err?
        pc_file = pc_file_result.unwrap
        files[pc_file.id] = pc_file
      end
      Ok.new(new(files))
    rescue error
      Err.new(VcpkgInstallation["Missing pkgconfig directory #{path}: #{error.message}"])
    end

    def fix_ordering(libs : Array(String)) : Array(String)
      required_lib_order = libs.dup

      3.times do
        required_lib_order.each do |rlib|
          required_lib_order << rlib
          pc_file = locate_pc_file_by_lib(rlib)
          next if pc_file.nil?
          pc_file.deps.each do |dep|
            dep_pc_file = files[dep]
            next if dep_pc_file.nil?
            dep_pc_file.libs.each do |dep_lib|
              removed = required_lib_order.delete(dep_lib)
              required_lib_order << removed if removed
            end
          end
        end
        break if required_lib_order == libs
        libs = required_lib_order
      end

      puts "cargo:warning=vcpkg gave up trying to resolve pkg-config ordering." if required_lib_order != libs
      required_lib_order
    end

    def locate_pc_file_by_lib(rlib : String) : PcFile?
      files.each do |_, pc_file|
        return pc_file if pc_file.libs.includes?(rlib)
      end
      nil
    end
  end
end
