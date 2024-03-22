module Vcpkg
  class VcpkgError < Exception
    def initialize(msg)
      super(msg)
    end

    def self.[](mess : String)
      new(mess)
    end
  end

  class VcpkgNotFound < VcpkgError
  end

  class NotMSVC < VcpkgError
  end

  class VcpkgInstallation < VcpkgError
  end

  class DisabledByEnv < VcpkgError
    def initialize(env : String)
      mess = "Disabled by ENV variable #{env}"
      super(mess)
    end
  end

  class LibNotFound < VcpkgError
  end

  class RequiredEnvMissing < VcpkgError
    def initialize(env : String)
      mess = "Required env missing: #{env}"
      super(mess)
    end
  end
end
