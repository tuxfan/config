python
import sys
sys.path.insert(0, '/home/bergen/.gdb/python')
from libstdcxx.v6.printers import register_libstdcxx_printers
register_libstdcxx_printers (None)
end
set debuginfod enabled on
