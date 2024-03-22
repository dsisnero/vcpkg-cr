require "option_parser"
require "./vcpkg"

ENV["VCPKGRS_DYNAMEC"] = "1"

def remove_vars
  ENV.delete("VCPKGRS_DYNAMIC")
  ENV.delete("CRYSTAL_CFG_TARGET_FEATURE")
end

target_triplet = "x86_64-pc-windows-msvc"
libname : String? = nil

the_parser = OptionParser.parse do |parser|
  parser.banner = <<-TEXT
  "Usage: vcpkg_lib NAME [flags]

  Examples
  vcpkg_lib zlib -l static
  vcpkg_lib zlib -l dll -t x86_64-pc-windows-msvc

  TEXT
  parser.on("-t", "--target TARGET_TRIPLET",
    "the rust toolchain triple to find libraries for, default: '86_64-pc-windows-msvc'") do |t|
    target_triplet = t
  end
  parser.on("-l", "--linkage LINKAGE", "Possible values: dll, static") do |linkage|
    case linkage
    when "dll"
      remove_vars
      ENV["VCPKGRS_DYNAMIC"] = "1"
    when "static"
      remove_vars
      ENV["CRYSTAL_CFG_TARGET_FEATURE"] = "crt-static"
    else
      STDERR.puts("Invalid value for linkage: #{linkage}. Must be [dll, static]")
      STDERR.puts(parser)
      exit(1)
    end
  end
  parser.on("-h", "--help", "Prints this help") do
    puts parser
    exit
  end

  parser.unknown_args do |arr|
    if arr.size == 1
      libname = arr[0]
    elsif arr.size == 0
      STDERR.puts "ERROR: you must specify a package name to search"
      STDERR.puts parser
      exit(1)
    else
      STDERR.puts "ERROR: only allowed one package name to search"
      STDERR.puts parser
      exit(1)
    end
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

ENV["TARGET"] = target_triplet
cfg = Vcpkg::Config.new
cfg.crystal_metadata = false
cfg.copy_dlls = false
begin
  if libname.nil?
    STDERR.puts "ERROR: you must specify a package name to search"
    STDERR.puts the_parser
    exit(1)
  end

  rlib = cfg.find_package(libname.not_nil!)
  if rlib.err?
    STDERR.puts "No package found: #{libname}"
    STDERR.puts rlib.unwrap_err.message
    exit(1)
  end

  if rlib && rlib.ok?
    rlib = rlib.unwrap.not_nil!.as(Vcpkg::Library)
  else
    STDERR.puts "No package found: #{libname}"
    STDERR.puts rlib
    exit(1)
  end

  puts "Found library #{libname}"
  unless rlib.include_paths.empty?
    puts "Include paths:"
    rlib.include_paths.each { |line| puts "  #{line}" }
  end

  unless rlib.link_paths.empty?
    puts "Library paths:"
    rlib.link_paths.each { |line| puts "  #{line}" }
  end

  unless rlib.link_paths.empty?
    puts "Runtime Library paths:"
    rlib.dll_paths.each { |line| puts "  #{line}" }
  end

  unless rlib.crystal_metadata.empty?
    puts "Crystal metadata:"
    rlib.crystal_metadata.each { |line| puts "  #{line}" }
  end

  unless rlib.found_dlls.empty?
    puts "Found DLLs:"
    rlib.found_dlls.each { |line| puts "  #{line}" }
  end

  unless rlib.found_libs.empty?
    puts "Found libs:"
    rlib.found_libs.each { |line| puts "  #{line}" }
  end

  unless rlib.found_names.empty?
    puts "Libraries linking names:"
    rlib.found_names.each { |line| puts "  #{line}" }
  end
rescue err : Exception
  puts "Failed: #{err}"
end
