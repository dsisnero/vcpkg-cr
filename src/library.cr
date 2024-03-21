module Vcpkg
  # Details of a package that was found
  class Library
    # Paths for the linker to search for static or import libraries
    property link_paths = [] of Path
    # Paths to search at runtme to find DLLs
    property dll_paths = [] of Path
    # Paths to include files
    property include_paths = [] of Path
    # cargo: metadata lines
    property cargo_metadata = [] of String
    # libraries found are static
    property is_static = false
    # DLLs found
    property found_dlls = [] of Path
    # static libs or import libs found
    property found_libs = [] of Path
    # link name of libraries found, this is useful to emit linker commands
    property found_names = [] of String
    # ports that are providing the libraries to link to, in port link order
    property ports = [] of String
    # the vcpkg triplet that has been selected
    property vcpkg_triplet = ""

    def initialize(@is_static, @vcpkg_triplet)
    end

    def to_s(io : IO)
      io << "Library: is_static: #{@is_static}, vcpkg_triplet: #{@vcpkg_triplet}\n"
      io << "link_paths: #{@link_paths}, dll_paths: #{@dll_paths}, include_paths: #{@include_paths}\n"
      io << "ports: #{@ports}, found_libs: #{@found_libs}, found_dlls: #{@found_dlls}\n"
      io << "found_names: #{@found_names}, cargo_metadata: #{@cargo_metadata}"
    end
  end
end
