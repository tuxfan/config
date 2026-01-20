#include <array>
#include <cmath>
#include <concepts>
#include <iostream>
#include <type_traits>

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

/*!
  Dense MxN matrix stored in row-major order.
  @tparam M Number of rows of the matrix.
  @tparam N Number of columns of the matrix.
  @tparam T Floating-point type.
 */
template<int M, int N, std::floating_point T>
struct dense_matrix {
  static constexpr bool square() { return M == N; }

  auto begin() { return data_.begin(); }
  auto begin() const { return data_.begin(); }
  auto end() { return data_.end(); }
  auto end() const { return data_.end(); }

  dense_matrix transpose() const {
    dense_matrix mt;
    for(auto i{0}; i<M; ++i) {
      for(auto j{0}; j<N; ++j) {
        mt[j][i] = data_[i][j];
      }
    }
    return mt;
  }

  auto & operator[](int i) {
    return data_[i];
  }
  auto const & operator[](int i) const {
    return data_[i];
  }


  friend std::ostream & operator<<(std::ostream & s, dense_matrix const & m) {
    for(auto r : m) {
      for(auto c : r) {
        s << c << " ";
      }
      s << std::endl;
    }
    return s;
  }

private:
  std::array<std::array<T, N>, M> data_{};
};

/*!
  In-place Cholesky-Banachiewicz factorization.
  @tparam M Number of rows of the matrix.
  @tparam N Number of columns of the matrix.
  @tparam T Floating-point type.
  @tparam C Clear upper values.
 */
template<int M, std::floating_point T, bool C = true>
void cholesky(dense_matrix<M, M, T> & m) {
  for(auto i{0}; i < M; ++i) {
    for(auto j{0}; j <= i; ++j) {
      T sum{0.0};
      for(auto k{0}; k < j; ++k) {
          sum += m[i][k] * m[j][k];
      }
      m[i][j] = i==j ? std::sqrt(m[i][i] - sum) :
        (1.0 / m[j][j] * (m[i][j] - sum));
    }
    if constexpr(C) {
      for(auto j{i+1}; j < M; ++j) {
        m[i][j] = 0.0;
      }
    }
  }
}

template<int M, int N, int P, std::floating_point T>
auto matrix_mult(dense_matrix<M, N, T> const & a, dense_matrix<N, P, T> const & b) {
  dense_matrix<M, P, T> m;
  for(auto i{0}; i<M; ++i) {
    for(auto j{0}; j<P; ++j) {
      for(auto k{0}; k<N; ++k) {
        m[i][j] += a[i][k]*b[k][j];
      }
    }
  }
  return m;
}

template<int M, std::floating_point T>
auto solve(dense_matrix<M, M, T> const & L, vector<M, T> const & b) {
  // Forward substitution
  vector<M, T> y;
  for(auto i{0}; i<M; ++i) {
    T sum{0.0};
    for(auto j{0}; j<i; ++j) {
      sum += L[i][j]*y[j];
    }
    y[i] = (b[i] - sum)/ L[i][i];
  }

  // Backward substitution
  vector<M, T> x;
  for(auto i=M-1; i >= 0; --i) {
    T sum{0.0};
    for(auto j{i+1}; j < M; ++j) {
      sum += L[j][i]*x[j];
    }
    x[i] = (y[i] - sum)/ L[i][i];
  }
  return x;
}

int main(int, char **) {
  #if 0
  dense_matrix<4, 4, double> m;
  m[0][0] = 2.0;
  m[0][1] = -1.0;

  m[1][0] = -1.0;
  m[1][1] = 2.0;
  m[1][2] = -1.0;

  m[2][1] = -1.0;
  m[2][2] = 2.0;
  m[2][3] = -1.0;

  m[3][2] = -1.0;
  m[3][3] = 2.0;
  #else
  dense_matrix<3, 3, double> m;
  m[0][0] = 4.0;
  m[0][1] = 2.0;
  m[0][2] = 6.0;

  m[1][0] = 2.0;
  m[1][1] = 2.0;
  m[1][2] = 5.0;

  m[2][0] = 6.0;
  m[2][1] = 5.0;
  m[2][2] = 22.0;

  vector<3, double> v{24.0, 18.0, 66.0};
  #endif

  std::cout << "original:\n" << m << std::endl;
  cholesky(m);
  std::cout << "factorization:\n" << m << std::endl;
  auto mt = m.transpose();
  std::cout << "transpose:\n" << mt << std::endl;
  std::cout << "mult:\n" << matrix_mult(m, mt) << std::endl;

  std::cout << "vector:\n" << v << std::endl;

  std::cout << solve(m, v) << std::endl;
	return 0;
} // main
