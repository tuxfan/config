#include <iostream>
#include <tuple>
#include <variant>
#include <vector>

//----------------------------------------------------------------------------//
// Generic view type.
//----------------------------------------------------------------------------//

template<typename STORAGE_TYPE>
struct data_view_u {

  void bind(char * data) {
    data_ = data;
  } // bind

  constexpr size_t size() {
    return sizeof(STORAGE_TYPE);
  } // size

  template<typename TYPE, size_t offset>
  TYPE & as() {
    return reinterpret_cast<TYPE &>(data_[offset]);
  } // as

private:
  char * data_;
}; // struct data_view_u

//----------------------------------------------------------------------------//
// Utility to compute byte offset from a tuple of types.
//----------------------------------------------------------------------------//

template<size_t index, typename STORAGE_TYPE>
constexpr size_t byte_offset() {
  using type_map_t = typename STORAGE_TYPE::type_map_t;

  static_assert(index < std::tuple_size<type_map_t>::value, "invalid index");

  if constexpr(index > 0) {
    using element = std::tuple_element_t<index, type_map_t>;
    return sizeof(std::tuple_element_t<index - 1, type_map_t>) +
      byte_offset<index - 1, STORAGE_TYPE>();
  } // if

  return 0;
} // byte_offset

//----------------------------------------------------------------------------//
// Model A.
//----------------------------------------------------------------------------//

struct ma_data_t {
  static constexpr double param1 = 1.5;

  double f0;
  double f1;
  float f2;
  int f3;

  using type_map_t = std::tuple<double, double, float, int>;
}; // ma_data_t

struct ma_t : public data_view_u<ma_data_t> {
  double & f0() { return as<double, 0>(); }
  double & f1() { return as<double, byte_offset<1, ma_data_t>()>(); }
  float & f2() { return as<float, byte_offset<2, ma_data_t>()>(); }
  int & f3() { return as<int, byte_offset<3, ma_data_t>()>(); }
}; // struct ma_t

//----------------------------------------------------------------------------//
// Test type to show size problem
//----------------------------------------------------------------------------//

struct test_data_t {
  int f3;
  double f0;
  double f1;
  float f2;
}; // test_data_t

//----------------------------------------------------------------------------//
// Model B.
//----------------------------------------------------------------------------//

struct mb_data_t {
  double f0;
}; // mb_data_t

struct mb_t : public data_view_u<mb_data_t> {
  double & f0() { return as<double, 0>(); }
}; // struct ma_t

struct print_model {

  void operator()(ma_t & m) {
    std::cout << "f0: " << m.f0() << std::endl;
    std::cout << "f1: " << m.f1() << std::endl;
    std::cout << "f2: " << m.f2() << std::endl;
    std::cout << "f3: " << m.f3() << std::endl;
  } // operator

  void operator()(mb_t & m) {
    std::cout << "f0: " << m.f0() << std::endl;
  } // operator

}; // struct print_model

int main(int argc, char ** argv) {

  std::cout << "tuple size: " <<
    sizeof(std::tuple<double, double, float, int>) << std::endl;
  std::cout << "1st ordering size: " << sizeof(ma_data_t) << std::endl;
  std::cout << "2nd ordering size: " << sizeof(test_data_t) << std::endl;

  std::vector<std::variant<ma_t, mb_t>> mvars;
  
  mvars.emplace_back(ma_t());
  mvars.emplace_back(mb_t());
  mvars.emplace_back(mb_t());
  mvars.emplace_back(ma_t());

  // allocate actual storage
  //std::vector<char> allocation(2*sizeof(ma_data_t) + 2*sizeof(mb_data_t));
  char * data = new char[2*sizeof(ma_data_t) + 2*sizeof(mb_data_t)];
  size_t offset{0};

  // bind and initialize data
  {
  auto & m = std::get<ma_t>(mvars[0]);
  m.bind(data);
  offset += m.size();
  m.f0() = 0.0;
  m.f1() = 1.0;
  m.f2() = 2.0;
  m.f3() = 3;
  }

  {
  auto & m = std::get<mb_t>(mvars[1]);
  m.bind(&data[offset]);
  offset += m.size();
  m.f0() = 100.0;
  }

  {
  auto & m = std::get<mb_t>(mvars[2]);
  m.bind(&data[offset]);
  offset += m.size();
  m.f0() = 200.0;
  }

  {
  auto & m = std::get<ma_t>(mvars[3]);
  m.bind(&data[offset]);
  m.f0() = 10.0;
  m.f1() = 11.0;
  m.f2() = 12.0;
  m.f3() = 13;
  }

  for(auto & v: mvars) {
    std::visit(print_model(), v);
#if 0
    std::visit([](auto && m) {
      using TYPE = std::decay_t<decltype(m)>;

      if constexpr(std::is_same_v<TYPE, ma_t>) {
        std::cout << "f0: " << m.f0() << std::endl;
        std::cout << "f1: " << m.f1() << std::endl;
        std::cout << "f2: " << m.f2() << std::endl;
        std::cout << "f3: " << m.f3() << std::endl;
      }
      else if(std::is_same_v<TYPE, mb_t>) {
        std::cout << "f0: " << m.f0() << std::endl;
      } // if
    }, v);
#endif
  } // for

  delete[] data;

	return 0;
} // main
