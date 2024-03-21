module Vcpkg
  # Details of a package that was found
  class Library
    # Paths for the linker to search for static or import libraries
    property link_paths = [] of Path
    # Paths to search at runtme to find DLLs
    property dll_paths = [] of Path
    # Paths to include files
    property include_paths = [] of Path
    # crystal: metadata lines
    property crystal_metadata = [] of String
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
  end
end
