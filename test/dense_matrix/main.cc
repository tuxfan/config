#include <array>
#include <cstddef>
#include <iostream>
#include <utility>

namespace ft {
using real_t = double;
}

template<std::size_t D, std::size_t PO>
class dense_matrix {
  static constexpr std::size_t DOFS1 = PO + 1;
  std::array<std::array<ft::real_t, D>, DOFS1> coords_;

  template<std::size_t ... II>
  void init(std::index_sequence<II...>) {
    (([&] {
      coords_[II][0] = 0.0;
      if constexpr (D > 1) { coords_[II][1] = 0.0; }
      if constexpr (D > 2) { coords_[II][2] = 0.0; }
      return true;
    }()),
    ...);
  }

public:
  dense_matrix() { init(std::make_integer_sequence<std::size_t, DOFS1>{}); }
  auto & operator[](std::size_t i) {
    return coords_[i];
  }
  auto begin() { return coords_.begin(); }
  auto begin() const { return coords_.begin(); }
  auto end() { return coords_.end(); }
  auto end() const { return coords_.end(); }
};

#if 0
template<std::size_t PO>
class dense_matrix<1, PO> {
  static constexpr std::size_t DOFS1 = PO + 1;
  std::array<std::array<ft::real_t, 1>, DOFS1> coords_;

  template<std::size_t ... II>
  void init(std::index_sequence<II...>) {
    ((coords_[II][0] = 0.0), ...);
  }

public:
  dense_matrix() { init(std::make_integer_sequence<std::size_t, DOFS1>{}); }
  auto & operator[](std::size_t i) {
    return coords_[i];
  }
  auto begin() { return coords_.begin(); }
  auto begin() const { return coords_.begin(); }
  auto end() { return coords_.end(); }
  auto end() const { return coords_.end(); }
};

template<std::size_t PO>
class dense_matrix<2, PO> {
  static constexpr std::size_t DOFS1 = PO + 1;
  std::array<std::array<ft::real_t, 2>, DOFS1> coords_;

  template<std::size_t ... II>
  void init(std::index_sequence<II...>) {
    ((coords_[II][0] = 0.0, coords_[II][1] = 0.0), ...);
  }

public:
  dense_matrix() { init(std::make_integer_sequence<std::size_t, DOFS1>{}); }
  auto & operator[](std::size_t i) {
    return coords_[i];
  }
  auto begin() { return coords_.begin(); }
  auto begin() const { return coords_.begin(); }
  auto end() { return coords_.end(); }
  auto end() const { return coords_.end(); }
};
#endif

int main(int argc, char ** argv) {
  dense_matrix<1, 4> m15;
  dense_matrix<2, 4> m25;

  m15[0][0] = 0.0;
  m15[1][0] = 0.2;
  m15[2][0] = 0.4;
  m15[3][0] = 0.6;
  m15[4][0] = 1.0;

  m25[0][0] = 0.0;
  m25[0][1] = 10.0;
  m25[1][0] = 0.2;
  m25[1][1] = 10.2;
  m25[2][0] = 0.4;
  m25[2][1] = 10.4;
  m25[3][0] = 0.6;
  m25[3][1] = 10.6;
  m25[4][0] = 1.0;
  m25[4][1] = 11.0;

  for(auto i: m15) {
    std::cout << i[0] << std::endl;
  }

  for(auto i: m25) {
    std::cout << i[0] << ", " << i[1] << std::endl;
  }

	return 0;
} // main
