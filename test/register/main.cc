#include <iostream>
#include <utility>

struct context {
  auto static & instance() {
    static context c;
    return c;
  }

  using target_type = int(*)();
  bool register_action(target_type a) {
    std::cout << "register" << std::endl;
    a();
    return true;
  }
};

enum cp {
  init,
  final
};

namespace detail {
template<template<std::size_t> typename F, cp CP, std::size_t ...II>
auto register_action(std::index_sequence<II...>) {
  bool r;
    (([&](){ r = context::instance().register_action(F<II>::action);}(), ...));
  return r;
}
} // namespace detail

template<template<std::size_t> typename F, cp CP>
auto register_action() {
  // Do a range of values
  return detail::register_action<F, CP>(std::index_sequence<1, 2, 3>{});
}

template<std::size_t I>
struct advance {
  static int action() {
    std::cout << "hello from " << I << std::endl;
    return 0;
  }
};

auto a = register_action<advance, cp::init>();

int main(int argc, char ** argv) {
	return 0;
} // main
