#include <array>
#include <iostream>
#include <print>
#include <vector>

namespace rk_methods {
// Dynamic

template<typename T>
struct row {
  T c;
  std::vector<T> a;
};

template<typename T>
struct heuns {
  static constexpr std::size_t stages() { return 2; }
  std::vector<row<T>> data{{0.0, {0.0}},
                           {0.5, {0.5}}};
  std::vector<T> b{0.0, 1.0};
};

template<typename T>
struct rk4 {
  static constexpr std::size_t stages() { return 4; }
  std::vector<row<T>> data{{0.0, {0.0}},
                           {0.5, {0.5}},
                           {0.5, {0.0, 0.5}},
                           {1.0, {0.0, 0.0, 1.0}}};
  std::vector<T> b{1.0/6.0, 1.0/3.0, 1.0/3.0, 1.0/6.0};
};

}

using heuns = rk_methods::heuns<double>;
using rk4 = rk_methods::rk4<double>;

#if 0
template<typename T>
struct heuns {
  static constexpr stages() { return 2; }
  static constexpr std::array<std::tuple<T, std::array<T, stages()>>, stages()> cmatrix;
  static constexpr std::array<T, stages()> nodes;
};

/*
template<typename T>
struct heuns_method {
  static constexpr int stages { return 2; }
  static constexpr std::array<std::array<T, 2>, 2> matrix{{{0.0, 0.0}, {0.5, 0.0}}};
  static constexpr std::array<T, 2> weights{0.0, 0.5};
  static constexpr std::array<T, 2> nodes{0.0, 1.0};


  auto begin() const { return 0; }
  auto end() const { return stages(); }
};
*/
#endif

template<typename T>
void f(T dt, T off) {
  std::cout << "evaluating at f(" << dt << ", " << off << ")\n";
}

#if 0
template<template<typename> BT>
struct erk {
  template<typename F>
  static operator()(F && f) {
    for(auto s{0})
  }
}
#endif

int main(int argc, char ** argv) {

  auto printer = [](auto const & m, std::string const & s) {
    std::println("{}", s);
    for(auto const & [c, mr]: m.data) {
      std::print("{:4f} | ", c);
      for(auto a: mr) {
        std::print("{:4f} ", a);
      }
      std::print("\n");
    }
  };

  {
  heuns i;
  printer(i, "Heun's Method");
  }

  {
  rk4 i;
  printer(i, "RK4 Method");
  }
	return 0;
} // main
