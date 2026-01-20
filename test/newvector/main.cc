#include <array>
#include <cmath>
#include <initializer_list>
#include <iostream>
#include <utility>

template<int M> concept LimitM = M < 10;

template<int M, std::floating_point T>
requires LimitM<M>
struct vector {

  vector() {}
  vector(std::initializer_list<T> const & l) {
    std::copy(l.begin(), l.end(), data_.begin());
  }

  auto & operator[](int i) {
    return data_[i];
  }
  auto const & operator[](int i) const {
    return data_[i];
  }

  T magnitude() const {
    return std::sqrt((*this) * (*this));
  }

  friend std::ostream & operator<<(std::ostream & s, vector const & v) {
    return insertion(s, v, std::make_integer_sequence<std::size_t, M>{});
  }

private:
  std::array<T, M> data_{};

  template<std::size_t ... II>
  static std::ostream & insertion(std::ostream & s, vector const & v, std::index_sequence<II...>) {
    ((s << v[II] << ' '), ...);
    return s;
  }
};

namespace detail {
template<int M, std::floating_point T, std::size_t ... II>
vector<M, T> scalar_multiply(T s, vector<M, T> const & v, std::index_sequence<II...>) {
  vector<M, T> r;
  ((r[II] = s * v[II]), ...);
  return r;
}

template<int M, std::floating_point T, std::size_t ... II>
T dot_product(vector<M, T> const & a, vector<M, T> const & b, std::index_sequence<II...>) {
  T r;
  ((r += a[II] * b[II]), ...);
  return r;
}

template<int M, std::floating_point T, std::size_t ... II>
vector<M, T> hadamard_product(vector<M, T> const & a, vector<M, T> const & b, std::index_sequence<II...>) {
  vector<M, T> r;
  ((r[II] = a[II] * b[II]), ...);
  return r;
}

template<int M, std::floating_point T, std::size_t ... II>
vector<M, T> addition(vector<M, T> const & a, vector<M, T> const & b, std::index_sequence<II...>) {
  vector<M, T> r;
  ((r[II] = a[II] + b[II]), ...);
  return r;
}

template<int M, std::floating_point T, std::size_t ... II>
vector<M, T> subtraction(vector<M, T> const & a, vector<M, T> const & b, std::index_sequence<II...>) {
  vector<M, T> r;
  ((r[II] = a[II] - b[II]), ...);
  return r;
}
}

template<int M, std::floating_point T>
vector<M, T> operator*(T s, vector<M, T> const & v) {
  return detail::scalar_multiply(s, v, std::make_integer_sequence<std::size_t, M>{});
}

template<int M, std::floating_point T>
T operator*(vector<M, T> const & a, vector<M, T> const & b) {
  return detail::dot_product(a, b, std::make_integer_sequence<std::size_t, M>{});
}

template<int M, std::floating_point T>
vector<M, T> operator%(vector<M, T> const & a, vector<M, T> const & b) {
  return detail::hadamard_product(a, b, std::make_integer_sequence<std::size_t, M>{});
}

template<int M, std::floating_point T>
vector<M, T> operator+(vector<M, T> const & a, vector<M, T> const & b) {
  return detail::addition(a, b, std::make_integer_sequence<std::size_t, M>{});
}

template<int M, std::floating_point T>
vector<M, T> operator-(vector<M, T> const & a, vector<M, T> const & b) {
  return detail::subtraction(a, b, std::make_integer_sequence<std::size_t, M>{});
}

int main(int argc, char ** argv) {
  vector<4, double> v{1.0, 2.0, 3.0, 4.0};
  vector<4, double> v2{2.0, 2.0, 2.0, 2.0};

  std::cout << v << std::endl;
  std::cout << v2 << std::endl;
  std::cout << "scalar multiplication: " << 4.0*v << std::endl;
  std::cout << "dot product: " << v*v2 << std::endl;
  std::cout << "hadamard product: " << v%v2 << std::endl;
  std::cout << "addition: " << v+v2 << std::endl;
  std::cout << "subtraction: " << v-v2 << std::endl;
  std::cout << "magnitude: " << v.magnitude() << std::endl;

  return 0;
} // main
