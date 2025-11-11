from spack.package import *
from spack_repo.builtin.packages.flecsi.package import Flecsi

class Flecsi(Flecsi):
    """
    Named version
    """
    version("barchetta-devel", commit="87a332c3eca5818c59d90f66be7b3a528534a8f2")
