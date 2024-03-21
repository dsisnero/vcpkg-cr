module Vcpkg
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

  class VcpkgInstallation < Error
  end

  class DisabledByEnv < Error
    def initialize(env : String)
      mess = "Disabled by ENV variable #{env}"
      super(mess)
    end
  end

  class LibNotFound < Error
  end
end
