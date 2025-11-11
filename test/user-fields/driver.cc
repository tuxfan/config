#include <flecsi/runtime.hh>

using namespace flecsi;

int
top_level_task(scheduler &) {
  return 0;
}

int
main(int argc, char ** argv) {
  const flecsi::getopt g;
  try {
    g(argc, argv);
  }
  catch(const std::logic_error & e) {
    std::cerr << e.what() << '\n' << g.usage(argc ? argv[0] : "");
    return 1;
  }

  const run::dependencies_guard dg;
  run::config cfg;

  runtime run(cfg);
  flog::add_output_stream("clog", std::clog, true);
  run.control<run::call>(top_level_task);
} // main
